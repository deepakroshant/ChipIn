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
    var personBalances: [PersonBalance] = []
    var overallNet: Decimal = 0
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
            if !otherUserIds.isEmpty {
                let users: [AppUser] = try await supabase
                    .from("users")
                    .select()
                    .in("id", values: otherUserIds)
                    .execute()
                    .value
                let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
                personBalances = netByUser.compactMap { userId, net in
                    guard let user = userMap[userId], net != 0 else { return nil }
                    return PersonBalance(id: userId, user: user, net: net)
                }.sorted { abs($0.net) > abs($1.net) }
            } else {
                personBalances = []
            }

            overallNet = personBalances.reduce(0) { $0 + $1.net }

            // Widget sync
            let defaults = UserDefaults(suiteName: "group.com.deepakroshant.chipin")
            defaults?.set(NSDecimalNumber(decimal: overallNet).doubleValue, forKey: "netBalance")
            WidgetCenter.shared.reloadAllTimelines()

        } catch {
            self.error = error.localizedDescription
        }
    }
}
