import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var username: String?
    var avatarURL: String?
    let email: String
    var defaultCurrency: String
    var interacContact: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, username
        case avatarURL = "avatar_url"
        case defaultCurrency = "default_currency"
        case interacContact = "interac_contact"
        case createdAt = "created_at"
    }

    /// Display handle: @username if set, otherwise first name
    var handle: String {
        if let u = username, !u.isEmpty { return "@\(u)" }
        return name.components(separatedBy: " ").first ?? name
    }
}
