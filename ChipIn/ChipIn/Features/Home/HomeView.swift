import SwiftUI
import Supabase

struct HomeView: View {
    @Binding var showAddExpense: Bool

    @Environment(AuthManager.self) var auth
    @AppStorage("hideBalances") private var hideBalances = false
    @AppStorage("accentColor") private var accentColorHex = "#F97316"
    @State private var vm = HomeViewModel()
    @State private var recentExpenses: [Expense] = []
    @State private var showProfile = false
    @State private var showRequestFriends = false
    @State private var debouncedRefreshTask: Task<Void, Never>?

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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if vm.isLoading && vm.personBalances.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(0..<4, id: \.self) { _ in
                                    PersonBalanceRowSkeleton()
                                    Divider().background(ChipInTheme.elevated).padding(.leading, 68)
                                }
                            }
                            .background(ChipInTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
                            .padding(.horizontal)
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
                                                Text(BalancePrivacy.currency(txn.amount, code: "CAD", hidden: hideBalances))
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
                .animation(ChipInTheme.spring, value: vm.error != nil)
                .animation(.easeInOut(duration: 0.32), value: vm.isLoading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showProfile = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            homeToolbarAvatar
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile")

                        Text("ChipIn")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: accentColorHex))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddExpense = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: accentColorHex))
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
                debouncedRefreshTask?.cancel()
                debouncedRefreshTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    if let id = auth.currentUser?.id {
                        await loadAll(userId: id)
                    }
                }
            }
        }
    }

    private var homeStatsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(
                    icon: "arrow.up.circle.fill",
                    title: "Paid this month",
                    value: vm.lentThisMonthCAD,
                    valueColor: ChipInTheme.label,
                    urgent: false,
                    hideAmount: hideBalances
                )
                statTile(
                    icon: "arrow.down.circle.fill",
                    title: "You're owed",
                    value: max(0, vm.overallNet),
                    valueColor: ChipInTheme.success,
                    urgent: false,
                    hideAmount: hideBalances
                )
            }
            HStack(spacing: 10) {
                statTile(
                    icon: "exclamationmark.circle.fill",
                    title: "You owe",
                    value: vm.pendingOwedCAD,
                    valueColor: vm.pendingOwedCAD > 50 ? ChipInTheme.danger : ChipInTheme.accent,
                    urgent: vm.pendingOwedCAD > 50,
                    hideAmount: hideBalances
                )
                streakTile
            }
        }
    }

    private var streakTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔥 Streak")
                .font(.caption.weight(.medium))
                .foregroundStyle(ChipInTheme.onSurfaceVariant)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(vm.streakDays)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(vm.streakDays >= 3 ? Color(red: 1.0, green: 0.6, blue: 0.1) : ChipInTheme.label)
                Text("day\(vm.streakDays == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChipInTheme.secondaryLabel)
            }
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

    private func statTile(icon: String, title: String, value: Decimal, valueColor: Color, urgent: Bool, hideAmount: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(valueColor.opacity(0.7))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChipInTheme.onSurfaceVariant)
            }
            Text(BalancePrivacy.currency(value, code: "CAD", hidden: hideAmount))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ChipInTheme.elevated.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
                .stroke(urgent ? ChipInTheme.danger.opacity(0.5) : Color.white.opacity(0.05), lineWidth: urgent ? 1.5 : 1)
        )
    }

    private func loadAll(userId: UUID) async {
        await vm.load(currentUserId: userId)
        recentExpenses = await fetchRecentExpenses()
    }

    /// Uses `expenses` ordered by time — RLS already limits rows to what you can see (paid, split, or group).
    private func fetchRecentExpenses() async -> [Expense] {
        let rows: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .order("created_at", ascending: false)
            .limit(8)
            .execute()
            .value) ?? []
        return Array(rows.prefix(5))
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

    @ViewBuilder
    private var homeToolbarAvatar: some View {
        let initial = String(auth.currentUser?.displayName.prefix(1) ?? "?").uppercased()
        let accent = Color(hex: accentColorHex)
        // Keep visual size ≤ nav title row (~28–32pt) so the system glass capsule doesn’t clip a 44pt disc.
        let plateDiameter: CGFloat = 30
        let ringDiameter: CGFloat = 28
        let photoSize: CGFloat = 22

        ZStack {
            // Soft “chip” plate — sized to sit inside the bar, not taller than “ChipIn” text.
            Circle()
                .fill(ChipInTheme.elevated)
                .frame(width: plateDiameter, height: plateDiameter)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                .shadow(color: accent.opacity(0.18), radius: 4, y: 0)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            accent,
                            accent.opacity(0.55),
                            Color.white.opacity(0.35),
                            accent.opacity(0.75),
                            accent
                        ],
                        center: .center
                    ),
                    lineWidth: 1.75
                )
                .frame(width: ringDiameter, height: ringDiameter)

            // SwiftUI.Group — not `Group` (Codable model in Models/Group.swift).
            SwiftUI.Group {
                if let urlStr = auth.currentUser?.avatarURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            avatarPlaceholder(initial: initial, accent: accent)
                        @unknown default:
                            avatarPlaceholder(initial: initial, accent: accent)
                        }
                    }
                } else {
                    avatarPlaceholder(initial: initial, accent: accent)
                }
            }
            .frame(width: photoSize, height: photoSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .frame(width: plateDiameter, height: plateDiameter)
        // Expand hit target without drawing outside the bar capsule.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
        .id("\(auth.currentUser?.avatarURL ?? "")-\(accentColorHex)")
    }

    private func avatarPlaceholder(initial: String, accent: Color) -> some View {
        Circle()
            .fill(accent.opacity(0.2))
            .overlay(
                Text(initial)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            )
    }
}
