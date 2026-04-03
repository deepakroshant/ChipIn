import SwiftUI

struct FriendsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if vm.isLoading && vm.personBalances.isEmpty {
                        ProgressView()
                            .tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if vm.personBalances.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.personBalances) { pb in
                                NavigationLink(destination: PersonDetailView(balance: pb)) {
                                    PersonBalanceRow(personBalance: pb)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                if pb.id != vm.personBalances.last?.id {
                                    Divider()
                                        .background(ChipInTheme.elevated)
                                        .padding(.leading, 66)
                                }
                            }
                        }
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
                .padding(.bottom, 16)
            }
            .background(ChipInTheme.background)
            .navigationTitle("Friends")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id {
                    await vm.load(currentUserId: id)
                }
            }
            .refreshable {
                if let id = auth.currentUser?.id {
                    await vm.load(currentUserId: id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            Text("No friends yet")
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)
            Text("Add an expense with someone and they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal)
    }
}
