import SwiftUI

@MainActor
@Observable
class GroupsViewModel {
    var groups: [Group] = []
    var isLoading = false
    private let service = GroupService()

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await service.fetchGroups(for: userId)
        } catch {
            print("GroupsViewModel error: \(error)")
        }
    }

    func createGroup(name: String, emoji: String, colour: String, userId: UUID) async {
        do {
            let group = try await service.createGroup(name: name, emoji: emoji, colour: colour, createdBy: userId)
            groups.insert(group, at: 0)
        } catch {
            print("Create group error: \(error)")
        }
    }
}
