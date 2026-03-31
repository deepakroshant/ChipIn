import SwiftUI
import WidgetKit
import Supabase
import PostgREST

@MainActor
@Observable
class HomeViewModel {
    var netBalance: Decimal = 0
    var recentActivity: [Expense] = []
    var isLoading = false

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let splits: [ExpenseSplit] = try await supabase
                .from("expense_splits")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("is_settled", value: false)
                .execute()
                .value

            let iOwe = splits.reduce(Decimal(0)) { $0 + $1.owedAmount }
            netBalance = -iOwe

            let defaults = UserDefaults(suiteName: "group.com.yourname.chipin")
            defaults?.set(NSDecimalNumber(decimal: netBalance).doubleValue, forKey: "netBalance")
            WidgetCenter.shared.reloadAllTimelines()

            let paidExpenses: [Expense] = try await supabase
                .from("expenses")
                .select()
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            recentActivity = paidExpenses
        } catch {
            print("HomeViewModel load error: \(error)")
        }
    }
}
