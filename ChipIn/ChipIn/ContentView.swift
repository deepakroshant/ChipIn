import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @State private var sync = SyncManager()
    @Environment(AuthManager.self) var auth

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                GroupsView()
                    .tabItem { Label("Groups", systemImage: "person.3.fill") }
                    .tag(1)

                InsightsView()
                    .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
                    .tag(3)
            }
            .tint(ChipInTheme.accent)
            .toolbarBackground(ChipInTheme.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)

            FloatingAddButton {
                showAddExpense = true
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
        }
        .task {
            await sync.startListening {
                NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            }
        }
    }
}
