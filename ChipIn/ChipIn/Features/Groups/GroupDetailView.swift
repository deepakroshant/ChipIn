import SwiftUI

struct GroupDetailView: View {
    let group: Group
    @Environment(AuthManager.self) var auth
    @State private var expenses: [Expense] = []
    @State private var members: [AppUser] = []
    @State private var showAddMember = false
    @State private var memberEmail = ""
    @State private var memberError: String?
    @State private var isAddingMember = false
    private let service = GroupService()
    private let expenseService = ExpenseService()

    var body: some View {
        List {
            // Members section
            Section {
                ForEach(members) { member in
                    HStack {
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(ChipInTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(ChipInTheme.accent.opacity(0.2))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.name)
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
                    memberEmail = ""
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
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .sheet(isPresented: $showAddMember) {
            addMemberSheet
        }
    }

    private var addMemberSheet: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Add Member")
                        .font(.title2.bold())
                        .foregroundStyle(ChipInTheme.label)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Email address", text: $memberEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(ChipInTheme.card)
                        .foregroundStyle(ChipInTheme.label)
                        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius).stroke(ChipInTheme.elevated, lineWidth: 1))

                    if let err = memberError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await addMember() }
                    } label: {
                        ZStack {
                            if isAddingMember {
                                ProgressView().tint(.black)
                            } else {
                                Text("Add to Group")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ChipInTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    }
                    .disabled(memberEmail.trimmingCharacters(in: .whitespaces).isEmpty || isAddingMember)

                    Spacer()
                }
                .padding(ChipInTheme.padding)
            }
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
        expenses = (try? await expensesTask) ?? []
        members = (try? await membersTask) ?? []
    }

    private func addMember() async {
        memberError = nil
        isAddingMember = true
        defer { isAddingMember = false }
        do {
            let user = try await service.addMember(groupId: group.id, email: memberEmail.trimmingCharacters(in: .whitespaces))
            members.append(user)
            showAddMember = false
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
}
