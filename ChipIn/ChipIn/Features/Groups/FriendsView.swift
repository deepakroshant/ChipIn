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
                            .fill(Color(hex: "#F97316").opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(friend.name.prefix(1))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(Color(hex: "#F97316"))
                            )
                        Text(friend.name)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Friends")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
