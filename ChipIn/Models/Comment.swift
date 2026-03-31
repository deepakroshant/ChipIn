import Foundation

struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    var body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case expenseId = "expense_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
