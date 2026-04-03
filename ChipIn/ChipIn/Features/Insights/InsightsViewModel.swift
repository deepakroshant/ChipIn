import SwiftUI
import Supabase
import PostgREST

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: String
    let emoji: String
    let total: Decimal
    let colour: Color
}

@MainActor
@Observable
class InsightsViewModel {
    var categoryStats: [CategoryStat] = []
    var monthlyTotal: Decimal = 0
    var settlements: [Settlement] = []
    var isLoading = false
    var error: String?

    private let colours: [Color] = [
        ChipInTheme.accent, Color(hex: "#3B82F6"),
        ChipInTheme.success, Color(hex: "#8B5CF6"),
        Color(hex: "#EC4899"), Color(hex: "#FBBF24")
    ]

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let cal = Calendar.current
            let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
            let formatter = ISO8601DateFormatter()

            let expenses: [Expense] = try await supabase
                .from("expenses")
                .select()
                .gte("created_at", value: formatter.string(from: startOfMonth))
                .execute()
                .value

            monthlyTotal = expenses.reduce(0) { $0 + $1.cadAmount }

            var byCategory: [String: Decimal] = [:]
            for expense in expenses {
                byCategory[expense.category, default: 0] += expense.cadAmount
            }

            categoryStats = byCategory.enumerated().map { idx, pair in
                let cat = ExpenseCategory(rawValue: pair.key) ?? .other
                return CategoryStat(
                    category: pair.key,
                    emoji: cat.emoji,
                    total: pair.value,
                    colour: colours[idx % colours.count]
                )
            }.sorted { $0.total > $1.total }

            settlements = try await supabase
                .from("settlements")
                .select()
                .or("from_user_id.eq.\(userId),to_user_id.eq.\(userId)")
                .order("settled_at", ascending: false)
                .limit(20)
                .execute()
                .value
        } catch {
            self.error = error.localizedDescription
        }
    }
}
