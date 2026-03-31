import SwiftUI

struct FriendsView: View {
    @Environment(AuthManager.self) var auth
    @State private var friends: [AppUser] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { friend in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(ChipInTheme.accent.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(friend.name.prefix(1))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(ChipInTheme.accent)
                            )
                        Text(friend.name)
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .listRowBackground(ChipInTheme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ChipInTheme.background)
            .navigationTitle("Friends")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
