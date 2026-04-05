import Foundation
import Supabase

struct Reaction: Codable, Identifiable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, emoji
        case expenseId = "expense_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct ReactionsService {
    func fetchReactions(expenseId: UUID) async throws -> [Reaction] {
        try await supabase
            .from("reactions")
            .select()
            .eq("expense_id", value: expenseId)
            .execute()
            .value
    }

    func toggleReaction(expenseId: UUID, userId: UUID, emoji: String, existing: [Reaction]) async throws {
        let alreadyReacted = existing.contains { $0.userId == userId && $0.emoji == emoji }
        if alreadyReacted {
            try await supabase
                .from("reactions")
                .delete()
                .eq("expense_id", value: expenseId)
                .eq("user_id", value: userId)
                .eq("emoji", value: emoji)
                .execute()
        } else {
            struct Insert: Encodable {
                let expense_id: String
                let user_id: String
                let emoji: String
            }
            try await supabase
                .from("reactions")
                .insert(Insert(expense_id: expenseId.uuidString, user_id: userId.uuidString, emoji: emoji))
                .execute()
        }
    }
}
