import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Chip In")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(ChipInTheme.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    BalanceCard(balance: vm.overallNet)
                        .padding(.horizontal)

                    if vm.personBalances.isEmpty {
                        emptyActivityPlaceholder
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Balances")
                                .font(.headline)
                                .foregroundStyle(ChipInTheme.label)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(vm.personBalances) { pb in
                                    NavigationLink(destination: PersonDetailView(balance: pb)) {
                                        PersonBalanceRow(personBalance: pb)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                    if pb.id != vm.personBalances.last?.id {
                                        Divider().background(ChipInTheme.elevated)
                                            .padding(.leading, 66)
                                    }
                                }
                            }
                            .background(ChipInTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .background(ChipInTheme.background)
            .toolbar(.hidden, for: .navigationBar)
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
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id {
                        await vm.load(currentUserId: id)
                    }
                }
            }
        }
    }

    private var emptyActivityPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            Text("No recent activity")
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)
            Text("Tap +, choose Friends, then add someone by ChipIn email or pick people you know. Group trips stay under Groups—you don’t need a group to split with one person.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
