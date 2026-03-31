import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var avatarURL: String?
    let email: String
    var defaultCurrency: String
    var interacContact: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarURL = "avatar_url"
        case defaultCurrency = "default_currency"
        case interacContact = "interac_contact"
        case createdAt = "created_at"
    }
}
