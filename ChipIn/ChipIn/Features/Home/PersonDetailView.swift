import SwiftUI
import Supabase
import PostgREST

struct PersonDetailView: View {
    let balance: PersonBalance
    @Environment(AuthManager.self) var auth
    @State private var expenses: [Expense] = []
    @State private var isLoading = false
    @State private var showSettleUp = false

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

                    // Settle up button (only if non-zero balance)
                    if balance.net != 0 {
                        Button {
                            showSettleUp = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text(theyOweMe ? "Request \(amountOwed, format: .currency(code: "CAD"))" : "Pay \(amountOwed, format: .currency(code: "CAD"))")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theyOweMe ? ChipInTheme.success : ChipInTheme.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                        }
                        .padding(.horizontal)
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
                                    ExpenseRow(expense: expense)
                                        .padding(.horizontal)
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
        .navigationTitle(balance.user.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ChipInTheme.card, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadExpenses() }
        .sheet(isPresented: $showSettleUp) {
            if let currentUser = auth.currentUser {
                if theyOweMe {
                    // They owe me — show from their perspective (they pay me)
                    SettleUpView(
                        fromUserId: balance.user.id,
                        toUser: currentUser,
                        amount: amountOwed,
                        groupId: nil
                    )
                } else {
                    // I owe them
                    SettleUpView(
                        fromUserId: currentUser.id,
                        toUser: balance.user,
                        amount: amountOwed,
                        groupId: nil
                    )
                }
            }
        }
    }

    private var personHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(ChipInTheme.avatarColor(for: balance.user.name).opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(balance.user.name.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(ChipInTheme.avatarColor(for: balance.user.name))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(balance.user.name)
                    .font(.headline)
                    .foregroundStyle(ChipInTheme.label)
                if balance.net == 0 {
                    Text("All settled up")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.success)
                } else if theyOweMe {
                    Text("owes you \(amountOwed, format: .currency(code: "CAD"))")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.success)
                } else {
                    Text("you owe \(amountOwed, format: .currency(code: "CAD"))")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.danger)
                }
            }

            Spacer()

            Text(amountOwed, format: .currency(code: "CAD"))
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
        }
    }
}
