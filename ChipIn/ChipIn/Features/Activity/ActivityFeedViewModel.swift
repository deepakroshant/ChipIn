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
    /// Settlement counterparty display name (`to_user` when actor is `from_user`).
    let peerName: String?

    init(
        id: UUID,
        kind: Kind,
        date: Date,
        actorName: String,
        actorId: UUID,
        peerName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.actorName = actorName
        self.actorId = actorId
        self.peerName = peerName
    }
}

@Observable @MainActor
class ActivityFeedViewModel {
    var items: [ActivityItem] = []
    var isLoading = false
    var error: String?

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Order by real time — never use `expense_id` (UUID) as a proxy for recency.
        async let expensesTask: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .order("created_at", ascending: false)
            .limit(35)
            .execute()
            .value) ?? []

        async let settlementsTask: [Settlement] = (try? await supabase
            .from("settlements")
            .select()
            .or("from_user_id.eq.\(currentUserId),to_user_id.eq.\(currentUserId)")
            .order("settled_at", ascending: false)
            .limit(15)
            .execute()
            .value) ?? []

        let (expenses, settlements) = await (expensesTask, settlementsTask)

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
        for s in settlements {
            feed.append(ActivityItem(
                id: s.id,
                kind: .settled(s),
                date: s.settledAt,
                actorName: userCache[s.fromUserId] ?? "Someone",
                actorId: s.fromUserId,
                peerName: userCache[s.toUserId] ?? "Someone"
            ))
        }

        items = feed.sorted { $0.date > $1.date }
    }
}
