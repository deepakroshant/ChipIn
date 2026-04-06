import SwiftUI
import WidgetKit
import Supabase
import PostgREST

struct PersonBalance: Identifiable {
    let id: UUID          // the other person's user ID
    let user: AppUser
    let net: Decimal      // positive = they owe YOU, negative = YOU owe them
}

@MainActor
@Observable
class HomeViewModel {
    /// Last successful load — used to detect net/pending deltas for SFX + toasts after remote changes.
    private var lastBalanceSnapshot: (overall: Decimal, pending: Decimal)?

    var personBalances: [PersonBalance] = []
    var overallNet: Decimal = 0
    /// Sum of CAD amounts for expenses you paid this calendar month.
    var lentThisMonthCAD: Decimal = 0
    /// Total you still owe others (sum of negative balances).
    var pendingOwedCAD: Decimal = 0
    /// Consecutive calendar days (ending today) on which the user paid for at least one expense.
    var streakDays: Int = 0
    var simplifiedTransactions: [SimplifiedTransaction] = []
    var isLoading = false
    var error: String?

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            // Fetch 1: splits where I am the DEBTOR (I owe someone)
            let myDebtSplits: [ExpenseSplit] = try await supabase
                .from("expense_splits")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("is_settled", value: false)
                .execute()
                .value

            // Fetch 2: expenses I paid
            let myExpenses: [Expense] = try await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: currentUserId)
                .execute()
                .value

            // Splits on my expenses where the debtor is NOT me AND not settled
            var owedToMeSplits: [ExpenseSplit] = []
            let myExpenseIds = myExpenses.map(\.id.uuidString)
            if !myExpenseIds.isEmpty {
                owedToMeSplits = try await supabase
                    .from("expense_splits")
                    .select()
                    .in("expense_id", values: myExpenseIds)
                    .neq("user_id", value: currentUserId)
                    .eq("is_settled", value: false)
                    .execute()
                    .value
            }

            // Client-side merge: net[otherUserId] = (what they owe me) - (what I owe them)
            var netByUser: [UUID: Decimal] = [:]

            // Others owe me: owedToMeSplits — counterparty is split.userId
            for split in owedToMeSplits {
                netByUser[split.userId, default: 0] += split.owedAmount
            }

            // I owe others: myDebtSplits — counterparty is the expense's paidBy
            let debtExpenseIds = Set(myDebtSplits.map(\.expenseId.uuidString))
            if !debtExpenseIds.isEmpty {
                let debtExpenses: [Expense] = try await supabase
                    .from("expenses")
                    .select()
                    .in("id", values: Array(debtExpenseIds))
                    .execute()
                    .value
                let expenseMap = Dictionary(uniqueKeysWithValues: debtExpenses.map { ($0.id, $0.paidBy) })
                for split in myDebtSplits {
                    if let paidBy = expenseMap[split.expenseId] {
                        netByUser[paidBy, default: 0] -= split.owedAmount
                    }
                }
            }

            // Fetch user profiles for all counterparties
            let otherUserIds = Array(netByUser.keys.map(\.uuidString))
            let newPersonBalances: [PersonBalance]
            let newSimplified: [SimplifiedTransaction]
            if !otherUserIds.isEmpty {
                let users: [AppUser] = try await supabase
                    .from("users")
                    .select()
                    .in("id", values: otherUserIds)
                    .execute()
                    .value
                let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
                newPersonBalances = netByUser.compactMap { userId, net in
                    guard let user = userMap[userId], net != 0 else { return nil }
                    return PersonBalance(id: userId, user: user, net: net)
                }.sorted { abs($0.net) > abs($1.net) }
                newSimplified = computeSimplified(balances: newPersonBalances, userMap: userMap, myId: currentUserId)
            } else {
                newPersonBalances = []
                newSimplified = []
            }

            let newOverallNet = newPersonBalances.reduce(0) { $0 + $1.net }
            let newPendingOwed = newPersonBalances.filter { $0.net < 0 }.reduce(0) { $0 + abs($1.net) }

            let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
            let iso = ISO8601DateFormatter().string(from: startOfMonth)
            let monthPaid: [Expense] = (try? await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: currentUserId)
                .gte("created_at", value: iso)
                .execute()
                .value) ?? []
            let newLentThisMonth = monthPaid.reduce(0) { $0 + $1.cadAmount }

            let allMyExpenses: [Expense] = (try? await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(60)
                .execute()
                .value) ?? []
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let uniqueDays = Set(allMyExpenses.map { calendar.startOfDay(for: $0.createdAt) })
            var streak = 0
            var checkDay = today
            while uniqueDays.contains(checkDay) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
                checkDay = prev
            }

            if let prev = lastBalanceSnapshot {
                BalanceFeedback.emitIfNeeded(
                    deltaOverall: newOverallNet - prev.overall,
                    deltaPending: newPendingOwed - prev.pending
                )
            }

            withAnimation(.easeInOut(duration: 0.28)) {
                personBalances = newPersonBalances
                simplifiedTransactions = newSimplified
                overallNet = newOverallNet
                pendingOwedCAD = newPendingOwed
                lentThisMonthCAD = newLentThisMonth
                streakDays = streak
            }
            lastBalanceSnapshot = (newOverallNet, newPendingOwed)

            // Widget sync — write richer data for the widget extension
            let defaults = UserDefaults(suiteName: "group.com.deepakroshant.chipin")
            defaults?.set(NSDecimalNumber(decimal: newOverallNet).doubleValue, forKey: "netBalance")
            let widgetBalances = newPersonBalances.prefix(3).map { pb -> [String: Any] in
                [
                    "name": pb.user.displayName,
                    "net": NSDecimalNumber(decimal: pb.net).doubleValue
                ]
            }
            defaults?.set(widgetBalances, forKey: "topBalances")
            WidgetCenter.shared.reloadAllTimelines()

        } catch {
            guard error.chipInShouldShowInUI() else { return }
            self.error = error.localizedDescription
        }
    }

    struct SimplifiedTransaction {
        let from: AppUser
        let to: AppUser
        let amount: Decimal
    }

    private func computeSimplified(balances: [PersonBalance], userMap: [UUID: AppUser], myId: UUID) -> [SimplifiedTransaction] {
        var nets: [UUID: Decimal] = [:]
        for pb in balances {
            nets[pb.user.id, default: 0] += pb.net
            nets[myId, default: 0] -= pb.net
        }

        var creditors = nets.filter { $0.value > 0 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        var debtors = nets.filter { $0.value < 0 }.map { ($0.key, abs($0.value)) }.sorted { $0.1 > $1.1 }

        var result: [SimplifiedTransaction] = []
        var ci = 0; var di = 0
        while ci < creditors.count && di < debtors.count {
            let (cid, camt) = creditors[ci]
            let (did, damt) = debtors[di]
            let settled = min(camt, damt)
            if let fromUser = userMap[did], let toUser = userMap[cid] {
                result.append(SimplifiedTransaction(from: fromUser, to: toUser, amount: settled))
            }
            creditors[ci].1 -= settled
            debtors[di].1 -= settled
            if creditors[ci].1 == 0 { ci += 1 }
            if debtors[di].1 == 0 { di += 1 }
        }
        return result.filter { $0.from.id == myId || $0.to.id == myId }
    }
}
