import Foundation
import Supabase

struct ActivityItem: Identifiable {
    enum Kind {
        case expenseAdded(Expense)
        case settled(Settlement)
    }
    let id: UUID
    let kind: Kind
    let date: Date
    let actorName: String
    let actorId: UUID
}

@Observable @MainActor
class ActivityFeedViewModel {
    var items: [ActivityItem] = []
    var isLoading = false
    var error: String?

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Expenses you're split on (paid by others)
        let yourSplits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select()
            .eq("user_id", value: currentUserId)
            .order("expense_id", ascending: false)
            .limit(30)
            .execute()
            .value) ?? []

        let splitExpenseIds = Array(Set(yourSplits.map(\.expenseId.uuidString)))
        var expenses: [Expense] = []
        if !splitExpenseIds.isEmpty {
            expenses = (try? await supabase
                .from("expenses")
                .select()
                .in("id", values: splitExpenseIds)
                .neq("paid_by", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value) ?? []
        }

        // Recent settlements involving current user
        let settlements: [Settlement] = (try? await supabase
            .from("settlements")
            .select()
            .or("from_user_id.eq.\(currentUserId),to_user_id.eq.\(currentUserId)")
            .order("settled_at", ascending: false)
            .limit(10)
            .execute()
            .value) ?? []

        // Fetch display names for actors
        var userCache: [UUID: String] = [:]
        let actorIds = Array(Set(
            expenses.map(\.paidBy) +
            settlements.map(\.fromUserId) +
            settlements.map(\.toUserId)
        ))
        if !actorIds.isEmpty {
            let users: [AppUser] = (try? await supabase
                .from("users")
                .select()
                .in("id", values: actorIds.map(\.uuidString))
                .execute()
                .value) ?? []
            for u in users { userCache[u.id] = u.displayName }
        }

        var feed: [ActivityItem] = []

        for exp in expenses {
            feed.append(ActivityItem(
                id: exp.id,
                kind: .expenseAdded(exp),
                date: exp.createdAt,
                actorName: userCache[exp.paidBy] ?? "Someone",
                actorId: exp.paidBy
            ))
        }
        for s in settlements where s.fromUserId != currentUserId {
            feed.append(ActivityItem(
                id: s.id,
                kind: .settled(s),
                date: s.settledAt,
                actorName: userCache[s.fromUserId] ?? "Someone",
                actorId: s.fromUserId
            ))
        }

        items = feed.sorted { $0.date > $1.date }
    }
}
