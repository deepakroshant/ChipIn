import Supabase
import PostgREST
import Foundation

/// RPC body for `find_user_by_email`. Explicit `Encodable` avoids main-actor–isolated synthesis (Swift 6).
private struct FindUserEmailParams: Sendable {
    let lookup_email: String
}

extension FindUserEmailParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lookup_email, forKey: .lookup_email)
    }

    private enum CodingKeys: String, CodingKey {
        case lookup_email
    }
}

enum GroupError: LocalizedError {
    case userNotFound
    case alreadyMember
    var errorDescription: String? {
        switch self {
        case .userNotFound: return "No ChipIn account found with that email."
        case .alreadyMember: return "That person is already in this group."
        }
    }
}

struct GroupService {
    func fetchGroups(for userId: UUID) async throws -> [Group] {
        let memberRows: [GroupMember] = try await supabase
            .from("group_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let groupIds = memberRows.map { $0.groupId }
        guard !groupIds.isEmpty else { return [] }

        return try await supabase
            .from("groups")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createGroup(name: String, emoji: String, colour: String, createdBy: UUID) async throws -> Group {
        let group: Group = try await supabase
            .from("groups")
            .insert([
                "name": name,
                "emoji": emoji,
                "colour": colour,
                "created_by": createdBy.uuidString
            ])
            .select()
            .single()
            .execute()
            .value

        try await supabase.from("group_members").insert([
            "group_id": group.id.uuidString,
            "user_id": createdBy.uuidString,
            "role": "admin"
        ]).execute()

        return group
    }

    func fetchExpenses(for groupId: UUID) async throws -> [Expense] {
        try await supabase
            .from("expenses")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Everyone you share a group with (for suggesting friends on personal splits).
    func fetchCoMembers(excludingSelf userId: UUID) async throws -> [AppUser] {
        let groups = try await fetchGroups(for: userId)
        var seen = Set<UUID>()
        seen.insert(userId)
        var users: [AppUser] = []
        for g in groups {
            let members = try await fetchMembers(for: g.id)
            for u in members where !seen.contains(u.id) {
                seen.insert(u.id)
                users.append(u)
            }
        }
        users.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return users
    }

    func searchUsers(_ query: String) async throws -> [AppUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        struct Params: Encodable {
            let query: String
        }
        let rows: [AppUser] = try await supabase
            .rpc("search_users", params: Params(query: trimmed))
            .execute()
            .value
        return rows
    }

    /// Resolve a registered user by email (requires `find_user_by_email` RPC in Supabase).
    func findUserByEmail(_ email: String) async throws -> AppUser? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rows: [AppUser] = try await supabase
            .rpc("find_user_by_email", params: FindUserEmailParams(lookup_email: trimmed))
            .execute()
            .value
        return rows.first
    }

    func addMember(groupId: UUID, email: String) async throws -> AppUser {
        guard let user = try await findUserByEmail(email) else {
            throw GroupError.userNotFound
        }
        let existing: [GroupMember] = try await supabase
            .from("group_members")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: user.id.uuidString)
            .execute()
            .value
        if !existing.isEmpty { throw GroupError.alreadyMember }
        try await supabase
            .from("group_members")
            .insert(["group_id": groupId.uuidString, "user_id": user.id.uuidString, "role": "member"])
            .execute()
        return user
    }

    func removeMember(groupId: UUID, userId: UUID) async throws {
        try await supabase
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func leaveGroup(groupId: UUID, userId: UUID) async throws {
        try await removeMember(groupId: groupId, userId: userId)
    }

    func fetchMembers(for groupId: UUID) async throws -> [AppUser] {
        let members: [GroupMember] = try await supabase
            .from("group_members")
            .select()
            .eq("group_id", value: groupId)
            .execute()
            .value

        guard !members.isEmpty else { return [] }

        return try await supabase
            .from("users")
            .select()
            .in("id", values: members.map { $0.userId.uuidString })
            .execute()
            .value
    }
}
