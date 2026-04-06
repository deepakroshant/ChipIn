import SwiftUI
import Supabase
import PostgREST

struct PersonDetailView: View {
    let balance: PersonBalance
    @Environment(AuthManager.self) var auth
    @AppStorage("hideBalances") private var hideBalances = false
    @State private var expenses: [Expense] = []
    @State private var isLoading = false
    @State private var showSettleUp = false
    @State private var nudgeSent = false
    @State private var isNudging = false
    @State private var splitsByExpense: [UUID: ExpenseSplit] = [:]
    private let nudgeService = NudgeService()

    private var amountOwed: Decimal { abs(balance.net) }
    private var theyOweMe: Bool { balance.net > 0 }

    var body: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Person header card
                    personHeader
                        .padding(.horizontal)
                        .padding(.top)

                    if !expenses.isEmpty {
                        settlementProgressBar
                    }

                    // Settle up button (only if non-zero balance)
                    if balance.net != 0 {
                        Button {
                            showSettleUp = true
                        } label: {
                            HStack {
                                Image(systemName: theyOweMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                Text(theyOweMe ? "Request via Interac" : "Pay via Interac")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theyOweMe ? ChipInTheme.success : ChipInTheme.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                        }
                        .padding(.horizontal)

                        if theyOweMe {
                            Button {
                                Task {
                                    isNudging = true
                                    defer { isNudging = false }
                                    let myName = auth.currentUser?.displayName ?? "Your friend"
                                    try? await nudgeService.sendNudge(
                                        toUserId: balance.user.id,
                                        fromName: myName,
                                        amount: amountOwed
                                    )
                                    nudgeSent = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { nudgeSent = false }
                                }
                            } label: {
                                HStack {
                                    if isNudging { ProgressView().tint(ChipInTheme.secondaryLabel) }
                                    else { Image(systemName: nudgeSent ? "checkmark" : "bell.badge") }
                                    Text(nudgeSent ? "Reminder sent!" : "Send a reminder")
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(ChipInTheme.card)
                                .foregroundStyle(nudgeSent ? ChipInTheme.success : ChipInTheme.secondaryLabel)
                                .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                            }
                            .padding(.horizontal)
                            .disabled(isNudging || nudgeSent)
                        }
                    }

                    // Expense history
                    if isLoading {
                        ProgressView()
                            .tint(ChipInTheme.accent)
                            .padding(.top, 40)
                    } else if expenses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                            Text("No shared expenses yet")
                                .foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared Expenses")
                                .font(.headline)
                                .foregroundStyle(ChipInTheme.label)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(expenses) { expense in
                                    ZStack(alignment: .topTrailing) {
                                        ExpenseRow(expense: expense)
                                            .padding(.horizontal)
                                        if let split = splitsByExpense[expense.id] {
                                            Text(split.isSettled ? "Settled ✓" : "Pending")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(split.isSettled ? ChipInTheme.success : ChipInTheme.accent)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(split.isSettled ? ChipInTheme.success.opacity(0.15) : ChipInTheme.accent.opacity(0.15))
                                                )
                                                .padding(.trailing, 20)
                                                .padding(.top, 10)
                                        }
                                    }
                                    if expense.id != expenses.last?.id {
                                        Divider()
                                            .background(ChipInTheme.elevated)
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .background(ChipInTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(balance.user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadExpenses() }
        .sheet(isPresented: $showSettleUp) {
            if let currentUser = auth.currentUser {
                if theyOweMe {
                    // They owe me — I'm requesting, they pay
                    SettleUpView(
                        fromUserId: balance.user.id,
                        toUser: currentUser,
                        amount: amountOwed,
                        groupId: nil,
                        isPayment: false
                    )
                    .environment(auth)
                } else {
                    // I owe them — I'm paying
                    SettleUpView(
                        fromUserId: currentUser.id,
                        toUser: balance.user,
                        amount: amountOwed,
                        groupId: nil,
                        isPayment: true
                    )
                    .environment(auth)
                }
            }
        }
    }

    private var settlementProgressBar: some View {
        let settled = expenses.filter { splitsByExpense[$0.id]?.isSettled == true }.count
        let total = expenses.count
        let pct = total > 0 ? Double(settled) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Settlement progress")
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                Spacer()
                Text("\(settled) / \(total) expenses settled")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ChipInTheme.elevated)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ChipInTheme.success)
                        .frame(width: geo.size.width * pct)
                        .animation(ChipInTheme.spring, value: pct)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
    }

    private var personHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(ChipInTheme.avatarColor(for: balance.user.id.uuidString).opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(balance.user.displayName.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(ChipInTheme.avatarColor(for: balance.user.id.uuidString))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(balance.user.displayName)
                    .font(.headline)
                    .foregroundStyle(ChipInTheme.label)
                if balance.net == 0 {
                    Text("All settled up")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.success)
                } else if theyOweMe {
                    Text("owes you \(BalancePrivacy.currency(amountOwed, code: "CAD", hidden: hideBalances))")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.success)
                } else {
                    Text("you owe \(BalancePrivacy.currency(amountOwed, code: "CAD", hidden: hideBalances))")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.danger)
                }
            }

            Spacer()

            Text(BalancePrivacy.currency(amountOwed, code: "CAD", hidden: hideBalances))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(theyOweMe ? ChipInTheme.success : ChipInTheme.danger)
        }
        .padding(ChipInTheme.cardPadding)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
    }

    private func loadExpenses() async {
        guard let myId = auth.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }

        // Fetch expenses paid by either person where the other is a split participant
        do {
            // Expenses I paid that include this person
            let myPaidExpenses: [Expense] = (try? await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: myId)
                .execute()
                .value) ?? []

            // Expenses they paid that include me
            let theirPaidExpenses: [Expense] = (try? await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: balance.user.id)
                .execute()
                .value) ?? []

            // Combine, deduplicate, sort newest first
            var combined = (myPaidExpenses + theirPaidExpenses)
            var seen = Set<UUID>()
            combined = combined.filter { seen.insert($0.id).inserted }
            expenses = combined.sorted { $0.createdAt > $1.createdAt }

            let expenseIds = expenses.map(\.id.uuidString)
            if !expenseIds.isEmpty {
                let splits: [ExpenseSplit] = (try? await supabase
                    .from("expense_splits")
                    .select()
                    .in("expense_id", values: expenseIds)
                    .eq("user_id", value: myId.uuidString)
                    .execute()
                    .value) ?? []
                splitsByExpense = Dictionary(uniqueKeysWithValues: splits.map { ($0.expenseId, $0) })
            } else {
                splitsByExpense = [:]
            }
        }
    }
}
