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
                                .fill(Color(hex: "#F97316").opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(member.name.prefix(1))
                                        .font(.caption).bold()
                                        .foregroundStyle(Color(hex: "#F97316"))
                                )
                            Text(member.name)
                                .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    }
                }
            }

            Section("Expenses") {
                ForEach(expenses) { expense in
                    ExpenseRow(expense: expense)
                        .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0A0A0A"))
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
