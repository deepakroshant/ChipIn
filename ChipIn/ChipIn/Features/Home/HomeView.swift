import SwiftUI
import Supabase

struct HomeView: View {
    @Binding var showAddExpense: Bool

    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()
    @State private var recentExpenses: [Expense] = []
    @State private var showProfile = false
    @State private var showRequestFriends = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ChipInTheme.background.ignoresSafeArea()

                Circle()
                    .fill(ChipInTheme.accent.opacity(0.22))
                    .frame(width: 220, height: 220)
                    .blur(radius: 70)
                    .offset(x: 80, y: -120)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 20) {
                        BalanceCard(
                            balance: vm.overallNet,
                            onRequest: { showRequestFriends = true }
                        )
                        .padding(.horizontal)

                        homeStatsRow
                            .padding(.horizontal)

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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                        }

                        if vm.isLoading && vm.personBalances.isEmpty {
                            ProgressView()
                                .tint(ChipInTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if vm.personBalances.isEmpty && recentExpenses.isEmpty {
                            emptyActivityPlaceholder
                        } else {
                            if !vm.personBalances.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Balances")
                                        .font(.title3.weight(.bold))
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
                                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                }
                            }

                            if !vm.simplifiedTransactions.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Simplified Payments")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(ChipInTheme.label)
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(ChipInTheme.accent)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)

                                    VStack(spacing: 0) {
                                        ForEach(Array(vm.simplifiedTransactions.enumerated()), id: \.offset) { idx, txn in
                                            HStack(spacing: 12) {
                                                Text(String(txn.from.displayName.prefix(1)).uppercased())
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(ChipInTheme.avatarColor(for: txn.from.id.uuidString))
                                                    .clipShape(Circle())
                                                Text("\(txn.from.displayName) → \(txn.to.displayName)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(ChipInTheme.label)
                                                Spacer()
                                                Text(txn.amount, format: .currency(code: "CAD"))
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(ChipInTheme.accent)
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                            if idx < vm.simplifiedTransactions.count - 1 {
                                                Divider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(ChipInTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                }
                            }

                            if !recentExpenses.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent activity")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(ChipInTheme.label)
                                        .padding(.horizontal)

                                    LazyVStack(spacing: 8) {
                                        ForEach(recentExpenses) { expense in
                                            ExpenseRow(expense: expense)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showProfile = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(ChipInTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile")

                        Text("ChipIn")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(ChipInTheme.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddExpense = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ChipInTheme.accent)
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environment(auth)
            }
            .sheet(isPresented: $showRequestFriends) {
                FriendsView()
                    .environment(auth)
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

    private var homeStatsRow: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Paid this month",
                value: vm.lentThisMonthCAD,
                valueColor: ChipInTheme.label
            )
            statTile(
                title: "You owe (pending)",
                value: vm.pendingOwedCAD,
                valueColor: ChipInTheme.accent
            )
        }
    }

    private func statTile(title: String, value: Decimal, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChipInTheme.onSurfaceVariant)
            Text(value, format: .currency(code: "CAD"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ChipInTheme.elevated.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func loadAll(userId: UUID) async {
        await vm.load(currentUserId: userId)
        recentExpenses = await fetchRecentExpenses(userId: userId)
    }

    private func fetchRecentExpenses(userId: UUID) async -> [Expense] {
        let paid: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .order("created_at", ascending: false)
            .limit(5)
            .execute()
            .value) ?? []

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

        var seen = Set<UUID>()
        let merged = (paid + involved)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
        return Array(merged)
    }

    private var emptyActivityPlaceholder: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ChipInTheme.accentGradient)
                    .frame(width: 80, height: 80)
                    .opacity(0.15)
                Text("💸").font(.system(size: 40))
            }
            VStack(spacing: 6) {
                Text("You're all clear!")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ChipInTheme.label)
                Text("Tap the + in the top-right for a full expense or Quick split.")
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
