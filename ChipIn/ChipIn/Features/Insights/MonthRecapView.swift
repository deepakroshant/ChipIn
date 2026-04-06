import SwiftUI
import Supabase

struct MonthStats {
    let monthName: String
    let totalSpent: Decimal
    let topCategory: String
    let topCategoryEmoji: String
    let friendCount: Int
    let expenseCount: Int
}

@MainActor
@Observable
final class MonthRecapViewModel {
    var stats: MonthStats?
    var isLoading = false

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let expenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .gte("created_at", value: formatter.string(from: startOfMonth))
            .execute()
            .value) ?? []

        let total = expenses.reduce(Decimal(0)) { $0 + $1.cadAmount }

        var catMap: [String: Decimal] = [:]
        for e in expenses { catMap[e.category, default: 0] += e.cadAmount }
        let topCat = catMap.max(by: { $0.value < $1.value })?.key ?? "other"

        let catEmoji: [String: String] = [
            "food": "🍕", "travel": "✈️", "rent": "🏠",
            "fun": "🎉", "utilities": "⚡", "other": "📦"
        ]

        let expenseIds = expenses.map(\.id.uuidString)
        let splits: [ExpenseSplit] = expenseIds.isEmpty ? [] : ((try? await supabase
            .from("expense_splits")
            .select()
            .in("expense_id", values: expenseIds)
            .neq("user_id", value: userId.uuidString)
            .execute()
            .value) ?? [])
        let friendCount = Set(splits.map(\.userId)).count

        let monthName = DateFormatter().monthSymbols[cal.component(.month, from: now) - 1]

        let key = topCat.lowercased()
        stats = MonthStats(
            monthName: monthName,
            totalSpent: total,
            topCategory: topCat.capitalized,
            topCategoryEmoji: catEmoji[key] ?? "📦",
            friendCount: friendCount,
            expenseCount: expenses.count
        )
    }
}

private struct RecapCard: View {
    let stats: MonthStats

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("⚡ ChipIn")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.26))
                Spacer()
                Text(stats.monthName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().background(.white.opacity(0.1))

            VStack(spacing: 6) {
                Text("You spent")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text(stats.totalSpent, format: .currency(code: "CAD"))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 28)

            HStack(spacing: 1) {
                subStat(label: "expenses", value: "\(stats.expenseCount)")
                Divider().background(.white.opacity(0.1)).frame(width: 1)
                subStat(label: "friends", value: "\(stats.friendCount)")
                Divider().background(.white.opacity(0.1)).frame(width: 1)
                subStat(label: "top category", value: "\(stats.topCategoryEmoji) \(stats.topCategory)")
            }
            .background(Color.white.opacity(0.05))

            Text("Split fair with ChipIn")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.08, blue: 0.06), Color(red: 0.06, green: 0.04, blue: 0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(width: 340)
    }

    private func subStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct MonthRecapView: View {
    let userId: UUID
    @State private var vm = MonthRecapViewModel()
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    if vm.isLoading {
                        ProgressView().tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else if let stats = vm.stats {
                        RecapCard(stats: stats)
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                            .padding(.horizontal)

                        if shareImage != nil {
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share Your Recap", systemImage: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ChipInTheme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ChipInTheme.ctaGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Monthly Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .task {
                await vm.load(userId: userId)
                renderCard()
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = shareImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    @MainActor
    private func renderCard() {
        guard let stats = vm.stats else { return }
        let renderer = ImageRenderer(content: RecapCard(stats: stats))
        renderer.scale = 3.0
        shareImage = renderer.uiImage
    }
}
