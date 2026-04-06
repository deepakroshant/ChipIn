import SwiftUI
import Supabase

private struct GroupMemberBalance: Identifiable {
    var id: String { "\(payer.id.uuidString)-\(payee.id.uuidString)" }
    let payer: AppUser
    let payee: AppUser
    let amount: Decimal
}

private func computeGroupBalances(
    expenses: [Expense],
    splits: [ExpenseSplit],
    members: [AppUser]
) -> [GroupMemberBalance] {
    let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    var net: [UUID: Decimal] = [:]
    for split in splits {
        guard let expense = expenses.first(where: { $0.id == split.expenseId }) else { continue }
        let paidBy = expense.paidBy
        let debtor = split.userId
        if debtor == paidBy { continue }
        net[paidBy, default: 0] += split.owedAmount
        net[debtor, default: 0] -= split.owedAmount
    }

    var creditors = net.filter { $0.value > 0 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    var debtors = net.filter { $0.value < 0 }.map { ($0.key, abs($0.value)) }.sorted { $0.1 > $1.1 }
    var result: [GroupMemberBalance] = []

    var ci = 0
    var di = 0
    while ci < creditors.count && di < debtors.count {
        var creditor = creditors[ci]
        var debtor = debtors[di]
        let settled = min(creditor.1, debtor.1)
        if let payerUser = memberMap[debtor.0], let payeeUser = memberMap[creditor.0] {
            result.append(GroupMemberBalance(payer: payerUser, payee: payeeUser, amount: settled))
        }
        creditor.1 -= settled
        debtor.1 -= settled
        creditors[ci] = creditor
        debtors[di] = debtor
        if creditor.1 == 0 { ci += 1 }
        if debtor.1 == 0 { di += 1 }
    }
    return result
}

struct GroupDetailView: View {
    let group: Group
    @Environment(AuthManager.self) var auth
    @State private var expenses: [Expense] = []
    @State private var members: [AppUser] = []
    @State private var showAddMember = false
    @State private var memberSearch = ""
    @State private var memberSearchResults: [AppUser] = []
    @State private var isSearchingMembers = false
    @State private var selectedUserToAdd: AppUser?
    @State private var memberError: String?
    @State private var isAddingMember = false
    private let service = GroupService()
    private let expenseService = ExpenseService()
    @State private var inviteLink: String?
    @State private var showShareSheet = false
    @State private var isGeneratingLink = false
    @State private var showBudget = false
    @State private var showLeaderboard = false
    @State private var groupSplits: [ExpenseSplit] = []

    private var memberBalances: [GroupMemberBalance] {
        computeGroupBalances(expenses: expenses, splits: groupSplits, members: members)
    }

    var body: some View {
        List {
            // Members section
            Section {
                ForEach(members) { member in
                    HStack {
                        Text(String(member.displayName.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(ChipInTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(ChipInTheme.accent.opacity(0.2))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.displayName)
                                .foregroundStyle(ChipInTheme.label)
                            if let u = member.username, !u.isEmpty {
                                Text("@\(u)")
                                    .font(.caption)
                                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                            }
                        }
                        Spacer()
                        if member.id == auth.currentUser?.id {
                            Text("You")
                                .font(.caption)
                                .foregroundStyle(ChipInTheme.tertiaryLabel)
                        }
                    }
                    .listRowBackground(ChipInTheme.card)
                    .swipeActions(edge: .trailing) {
                        if member.id == auth.currentUser?.id {
                            Button(role: .destructive) {
                                Task { await leave(userId: member.id) }
                            } label: {
                                Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } else {
                            Button(role: .destructive) {
                                Task { await removeMember(userId: member.id) }
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }

                Button {
                    memberSearch = ""
                    memberSearchResults = []
                    selectedUserToAdd = nil
                    memberError = nil
                    showAddMember = true
                } label: {
                    Label("Add Member", systemImage: "person.badge.plus")
                        .foregroundStyle(ChipInTheme.accent)
                }
                .listRowBackground(ChipInTheme.card)
            } header: {
                Text("Members (\(members.count))")
            }

            if !memberBalances.isEmpty {
                Section("Balances") {
                    ForEach(memberBalances) { b in
                        HStack(spacing: 12) {
                            Text(String(b.payer.displayName.prefix(1)).uppercased())
                                .font(.caption.bold()).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(ChipInTheme.avatarColor(for: b.payer.id.uuidString))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(b.payer.displayName) owes \(b.payee.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(ChipInTheme.label)
                            }
                            Spacer()
                            Text(b.amount, format: .currency(code: "CAD"))
                                .font(.subheadline.bold())
                                .foregroundStyle(ChipInTheme.danger)
                        }
                        .listRowBackground(ChipInTheme.card)
                    }
                }
            }

            // Expenses section
            Section("Expenses") {
                if expenses.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                        Text("No expenses yet")
                            .font(.subheadline.bold())
                            .foregroundStyle(ChipInTheme.label)
                        Text("Tap + to add the first expense")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .listRowBackground(ChipInTheme.card)
                } else {
                    ForEach(expenses) { expense in
                        ExpenseRow(expense: expense) {
                            Task { await deleteExpense(expense) }
                        }
                        .listRowBackground(ChipInTheme.card)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ChipInTheme.background)
        .navigationTitle("\(group.emoji) \(group.name)")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        Task { await generateInviteLink() }
                    } label: {
                        if isGeneratingLink {
                            ProgressView().tint(ChipInTheme.accent).scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(ChipInTheme.accent)
                        }
                    }
                    Button {
                        showBudget = true
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(ChipInTheme.accent)
                    }
                    Button {
                        showLeaderboard = true
                    } label: {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(ChipInTheme.accent)
                    }
                    .accessibilityLabel("Group Stats")
                }
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .sheet(isPresented: $showAddMember) {
            addMemberSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if let link = inviteLink {
                ShareSheet(items: [link])
            }
        }
        .sheet(isPresented: $showBudget) {
            GroupBudgetView(group: group, totalSpent: expenses.reduce(0) { $0 + $1.totalAmount })
        }
        .sheet(isPresented: $showLeaderboard) {
            GroupLeaderboardView(group: group, members: members)
        }
    }

    private var addMemberSheet: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Member")
                        .font(.title2.bold())
                        .foregroundStyle(ChipInTheme.label)

                    Text("Search by name, @username, or email — pick someone who already uses ChipIn.")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.onSurfaceVariant)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                        TextField("Search…", text: $memberSearch)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(ChipInTheme.label)
                            .onChange(of: memberSearch) { _, _ in
                                Task { await searchMembersForGroup() }
                            }
                        if isSearchingMembers {
                            ProgressView().tint(ChipInTheme.accent).scaleEffect(0.85)
                        } else if !memberSearch.isEmpty {
                            Button {
                                memberSearch = ""
                                memberSearchResults = []
                                selectedUserToAdd = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                            }
                        }
                    }
                    .padding(14)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                    if !memberSearchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(memberSearchResults) { user in
                                    let selected = selectedUserToAdd?.id == user.id
                                    Button {
                                        selectedUserToAdd = user
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(String(user.displayName.prefix(1)).uppercased())
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                                .frame(width: 40, height: 40)
                                                .background(ChipInTheme.avatarColor(for: user.id.uuidString))
                                                .clipShape(Circle())
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(user.displayName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(ChipInTheme.label)
                                                Text(user.handle)
                                                    .font(.caption)
                                                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                                            }
                                            Spacer()
                                            if selected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(ChipInTheme.accent)
                                            }
                                        }
                                        .padding(12)
                                        .background(selected ? ChipInTheme.elevated : ChipInTheme.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 280)
                    } else if memberSearch.trimmingCharacters(in: .whitespaces).count >= 2, !isSearchingMembers {
                        Text("No matches — try another spelling or email.")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                    }

                    if let err = memberError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.danger)
                    }

                    Button {
                        Task { await addMember() }
                    } label: {
                        ZStack {
                            if isAddingMember {
                                ProgressView().tint(ChipInTheme.onPrimary)
                            } else {
                                Text("Add to Group")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ChipInTheme.onPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            if selectedUserToAdd == nil {
                                ChipInTheme.elevated
                            } else {
                                ChipInTheme.ctaGradient
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius, style: .continuous))
                    }
                    .disabled(selectedUserToAdd == nil || isAddingMember)

                    Spacer()
                }
                .padding(ChipInTheme.padding)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMember = false }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadAll() async {
        async let expensesTask = service.fetchExpenses(for: group.id)
        async let membersTask = service.fetchMembers(for: group.id)
        async let splitsTask = service.fetchGroupSplits(for: group.id)
        expenses = (try? await expensesTask) ?? []
        members = (try? await membersTask) ?? []
        groupSplits = (try? await splitsTask) ?? []
    }

    private func searchMembersForGroup() async {
        let trimmed = memberSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            memberSearchResults = []
            return
        }
        isSearchingMembers = true
        defer { isSearchingMembers = false }
        let found = (try? await service.searchUsers(trimmed)) ?? []
        let memberIds = Set(members.map(\.id))
        let me = auth.currentUser?.id
        memberSearchResults = found.filter { u in
            !memberIds.contains(u.id) && u.id != me
        }
    }

    private func addMember() async {
        memberError = nil
        guard let user = selectedUserToAdd else {
            memberError = "Select someone from the list."
            return
        }
        isAddingMember = true
        defer { isAddingMember = false }
        do {
            let added = try await service.addMember(groupId: group.id, user: user)
            members.append(added)
            showAddMember = false
            selectedUserToAdd = nil
            memberSearch = ""
            memberSearchResults = []
        } catch {
            memberError = error.localizedDescription
        }
    }

    private func removeMember(userId: UUID) async {
        try? await service.removeMember(groupId: group.id, userId: userId)
        members.removeAll { $0.id == userId }
    }

    private func leave(userId: UUID) async {
        try? await service.leaveGroup(groupId: group.id, userId: userId)
        members.removeAll { $0.id == userId }
    }

    private func deleteExpense(_ expense: Expense) async {
        try? await expenseService.deleteExpense(id: expense.id)
        expenses.removeAll { $0.id == expense.id }
        NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
    }

    private func generateInviteLink() async {
        guard let userId = auth.currentUser?.id else { return }
        isGeneratingLink = true
        defer { isGeneratingLink = false }
        struct Insert: Encodable { let group_id: String; let created_by: String }
        struct Invite: Decodable { let id: String }
        let invite: Invite? = try? await supabase
            .from("group_invites")
            .insert(Insert(group_id: group.id.uuidString, created_by: userId.uuidString))
            .select()
            .single()
            .execute()
            .value
        if let id = invite?.id {
            inviteLink = "chipin://join/\(id)"
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
