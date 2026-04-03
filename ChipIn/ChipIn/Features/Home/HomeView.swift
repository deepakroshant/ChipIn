import SwiftUI
import Supabase

struct HomeView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()
    @State private var recentExpenses: [Expense] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Chip In")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ChipInTheme.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    BalanceCard(balance: vm.overallNet)
                        .padding(.horizontal)

                    // Error banner
                    if let errorMessage = vm.error {
                        HStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                vm.error = nil
                            } label: {
                                Text("✕")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ChipInTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Loading overlay when no data yet
                    if vm.isLoading && vm.personBalances.isEmpty {
                        ProgressView()
                            .tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if vm.personBalances.isEmpty && recentExpenses.isEmpty {
                        emptyActivityPlaceholder
                    } else {
                        // Balances section
                        if !vm.personBalances.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Balances")
                                    .font(.headline)
                                    .foregroundStyle(ChipInTheme.label)
                                    .padding(.horizontal)

                                LazyVStack(spacing: 0) {
                                    ForEach(vm.personBalances) { pb in
                                        NavigationLink(destination: PersonDetailView(balance: pb)) {
                                            PersonBalanceRow(personBalance: pb)
                                                .padding(.horizontal)
                                        }
                                        .buttonStyle(.plain)
                                        if pb.id != vm.personBalances.last?.id {
                                            Divider().background(ChipInTheme.elevated)
                                                .padding(.leading, 66)
                                        }
                                    }
                                }
                                .background(ChipInTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }

                        // Recent Activity section
                        if !recentExpenses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Activity")
                                    .font(.headline)
                                    .foregroundStyle(ChipInTheme.label)
                                    .padding(.horizontal)

                                LazyVStack(spacing: 0) {
                                    ForEach(recentExpenses) { expense in
                                        ExpenseRow(expense: expense)
                                            .padding(.horizontal)
                                        if expense.id != recentExpenses.last?.id {
                                            Divider().background(ChipInTheme.elevated)
                                                .padding(.leading, 66)
                                        }
                                    }
                                }
                                .background(ChipInTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .background(ChipInTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id {
                    await loadAll(userId: id)
                }
            }
            .refreshable {
                if let id = auth.currentUser?.id {
                    await loadAll(userId: id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id {
                        await loadAll(userId: id)
                    }
                }
            }
        }
    }

    private func loadAll(userId: UUID) async {
        await vm.load(currentUserId: userId)
        recentExpenses = await fetchRecentExpenses(userId: userId)
    }

    private func fetchRecentExpenses(userId: UUID) async -> [Expense] {
        // Query 1: expenses I paid
        let paid: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .order("created_at", ascending: false)
            .limit(5)
            .execute()
            .value) ?? []

        // Query 2: expenses I have a split in (as debtor)
        let splits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select()
            .eq("user_id", value: userId)
            .order("expense_id", ascending: false)
            .limit(5)
            .execute()
            .value) ?? []

        var involved: [Expense] = []
        let splitExpenseIds = splits.map(\.expenseId.uuidString)
        if !splitExpenseIds.isEmpty {
            involved = (try? await supabase
                .from("expenses")
                .select()
                .in("id", values: splitExpenseIds)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value) ?? []
        }

        // Merge, deduplicate, sort descending, take top 5
        var seen = Set<UUID>()
        let merged = (paid + involved)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
        return Array(merged)
    }

    private var emptyActivityPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            Text("No recent activity")
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)
            Text("Tap +, choose Friends, then add someone by ChipIn email or pick people you know. Group trips stay under Groups—you don't need a group to split with one person.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
