import SwiftUI

struct GroupDetailView: View {
    let group: Group
    @State private var expenses: [Expense] = []
    @State private var members: [AppUser] = []
    private let service = GroupService()

    var body: some View {
        List {
            if !members.isEmpty {
                Section("Members") {
                    ForEach(members) { member in
                        HStack {
                            Circle()
                                .fill(ChipInTheme.accent.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(member.name.prefix(1))
                                        .font(.caption).bold()
                                        .foregroundStyle(ChipInTheme.accent)
                                )
                            Text(member.name)
                                .foregroundStyle(ChipInTheme.label)
                        }
                        .listRowBackground(ChipInTheme.card)
                    }
                }
            }

            Section("Expenses") {
                ForEach(expenses) { expense in
                    ExpenseRow(expense: expense)
                        .listRowBackground(ChipInTheme.card)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ChipInTheme.background)
        .navigationTitle("\(group.emoji) \(group.name)")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            async let expensesTask = service.fetchExpenses(for: group.id)
            async let membersTask = service.fetchMembers(for: group.id)
            expenses = (try? await expensesTask) ?? []
            members = (try? await membersTask) ?? []
        }
    }
}
