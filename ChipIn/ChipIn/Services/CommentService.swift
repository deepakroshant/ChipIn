import Supabase
import Foundation

struct CommentService {
    func fetchComments(for expenseId: UUID) async throws -> [Comment] {
        try await supabase
            .from("comments")
            .select()
            .eq("expense_id", value: expenseId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(expenseId: UUID, userId: UUID, body: String) async throws -> Comment {
        struct Insert: Encodable {
            let expense_id: String
            let user_id: String
            let body: String
        }
        return try await supabase
            .from("comments")
            .insert(Insert(
                expense_id: expenseId.uuidString,
                user_id: userId.uuidString,
                body: body
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteComment(id: UUID) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
