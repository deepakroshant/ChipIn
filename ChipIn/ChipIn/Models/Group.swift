import Foundation

struct Group: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var colour: String
    let createdBy: UUID
    let createdAt: Date
    var budget: Decimal?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colour
        case createdBy = "created_by"
        case createdAt = "created_at"
        case budget
    }
}

struct GroupMember: Codable, Hashable {
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date
    var role: String

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case role
    }
}
