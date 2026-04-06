import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var username: String?
    var avatarURL: String?
    let email: String
    var defaultCurrency: String
    var interacContact: String?
    /// When false, APNs uses the system default instead of bundled `money_in.caf` / `money_out.caf`.
    var pushCustomSoundEnabled: Bool?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, username
        case avatarURL = "avatar_url"
        case defaultCurrency = "default_currency"
        case interacContact = "interac_contact"
        case pushCustomSoundEnabled = "push_custom_sound_enabled"
        case createdAt = "created_at"
    }

    /// Display handle: @username if set, otherwise first name
    var handle: String {
        if let u = username, !u.isEmpty { return "@\(u)" }
        return name.components(separatedBy: " ").first ?? name
    }

    /// Human-friendly name for lists (avoids raw "User" / empty metadata).
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if !trimmed.isEmpty, !Self.placeholderNames.contains(lower) {
            return trimmed
        }
        if let u = username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            return u
        }
        if let local = email.split(separator: "@").first.map(String.init) {
            var s = local
            if s.lowercased().hasPrefix("guest-") { s = String(s.dropFirst(6)) }
            if s.lowercased().hasPrefix("user-") { s = String(s.dropFirst(5)) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty,
               !email.hasSuffix("@local.invalid"),
               !email.hasSuffix("@local.dev"),
               !email.hasSuffix("@apple.private") {
                return s.prefix(1).uppercased() + s.dropFirst().lowercased()
            }
        }
        if email.contains("guest") || email.contains("@local.") { return "Guest" }
        return "ChipIn member"
    }

    private static let placeholderNames: Set<String> = ["user", "guest", "apple user", ""]
}
