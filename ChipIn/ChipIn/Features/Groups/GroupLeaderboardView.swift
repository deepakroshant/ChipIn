import SwiftUI

struct GroupStat: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    let winnerName: String
    let winnerId: UUID
    let value: String
    let subtitle: String
}

struct GroupLeaderboardView: View {
    let group: Group
    let members: [AppUser]
    @Environment(\.dismiss) var dismiss
    @State private var stats: [GroupStat] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(ChipInTheme.accent)
                } else if stats.isEmpty {
                    VStack(spacing: 12) {
                        Text("🏜️").font(.system(size: 48))
                        Text("Not enough data yet")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                        Text("Add some expenses first!")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            Text("🏆 \(group.name) Hall of Fame")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(ChipInTheme.label)
                                .padding(.top, 8)
                                .multilineTextAlignment(.center)

                            ForEach(stats) { stat in
                                statCard(stat)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Group Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .task { await loadStats() }
        }
        .presentationDetents([.large])
    }

    private func statCard(_ stat: GroupStat) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ChipInTheme.avatarColor(for: stat.winnerId.uuidString).opacity(0.25))
                    .frame(width: 44, height: 44)
                Text(stat.emoji)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                Text(stat.winnerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChipInTheme.label)
                Text(stat.subtitle)
                    .font(.caption2)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
            }
            Spacer()
            Text(stat.value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ChipInTheme.accent)
        }
        .padding(14)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    }

    private func loadStats() async {
        defer { isLoading = false }

        let expenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("group_id", value: group.id)
            .execute()
            .value) ?? []

        guard !expenses.isEmpty else { return }

        let expenseIds = expenses.map(\.id.uuidString)
        let splits: [ExpenseSplit] = expenseIds.isEmpty ? [] :
            (try? await supabase
                .from("expense_splits")
                .select()
                .in("expense_id", values: expenseIds)
                .execute()
                .value) ?? []

        func user(for id: UUID) -> AppUser? { members.first { $0.id == id } }

        var result: [GroupStat] = []

        // Biggest spender: paid the most upfront
        var totalPaid: [UUID: Decimal] = [:]
        for e in expenses { totalPaid[e.paidBy, default: 0] += e.cadAmount }
        if let (topId, topAmt) = totalPaid.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Biggest Spender", emoji: "💸",
                winnerName: u.displayName, winnerId: u.id,
                value: topAmt.formatted(.currency(code: "CAD")),
                subtitle: "Paid the most upfront in this group"
            ))
        }

        // Most debt: owes the most (unsettled splits)
        var totalOwed: [UUID: Decimal] = [:]
        for s in splits where !s.isSettled { totalOwed[s.userId, default: 0] += s.owedAmount }
        if let (topId, topAmt) = totalOwed.max(by: { $0.value < $1.value }),
           let u = user(for: topId), topAmt > 0 {
            result.append(GroupStat(
                title: "Most Debt", emoji: "😬",
                winnerName: u.displayName, winnerId: u.id,
                value: topAmt.formatted(.currency(code: "CAD")),
                subtitle: "Still owes the most — nudge them!"
            ))
        }

        // Best settler: most settled splits
        var settledCount: [UUID: Int] = [:]
        for s in splits where s.isSettled { settledCount[s.userId, default: 0] += 1 }
        if let (topId, count) = settledCount.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Best Settler", emoji: "⚡",
                winnerName: u.displayName, winnerId: u.id,
                value: "\(count) paid",
                subtitle: "Cleared debts the fastest"
            ))
        }

        // Generous host: most expenses picked up
        var expCount: [UUID: Int] = [:]
        for e in expenses { expCount[e.paidBy, default: 0] += 1 }
        if let (topId, count) = expCount.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Generous Host", emoji: "🙌",
                winnerName: u.displayName, winnerId: u.id,
                value: "\(count) expense\(count == 1 ? "" : "s")",
                subtitle: "Picks up the tab the most"
            ))
        }

        stats = result
    }
}
