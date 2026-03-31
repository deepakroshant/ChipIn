import Foundation

struct Settlement: Codable, Identifiable, Hashable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    var amount: Decimal
    var groupId: UUID?
    var method: String
    let settledAt: Date

    enum CodingKeys: String, CodingKey {
        case id, amount, method
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case groupId = "group_id"
        case settledAt = "settled_at"
    }
}
