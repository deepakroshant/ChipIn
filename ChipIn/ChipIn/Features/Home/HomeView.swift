import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BalanceCard(balance: vm.netBalance)
                        .padding(.horizontal)

                    if !vm.recentActivity.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(vm.recentActivity) { expense in
                                    ExpenseRow(expense: expense)
                                        .padding(.horizontal)
                                    Divider().background(Color(hex: "#2C2C2E"))
                                }
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Chip In")
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
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
            .onReceive(NotificationCenter.default.publisher(for: .dataDidUpdate)) { _ in
                Task {
                    if let id = auth.currentUser?.id {
                        await vm.load(currentUserId: id)
                    }
                }
            }
        }
    }
}
