import Foundation

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
