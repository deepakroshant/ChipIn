import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @State private var sync = SyncManager()
    @Environment(AuthManager.self) var auth

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showAddExpense: $showAddExpense)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ActivityFeedView()
                .environment(auth)
                .tabItem { Label("Activity", systemImage: "bell.fill") }
                .tag(1)

            GroupsView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }
                .tag(2)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(3)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(4)
        }
        .tint(ChipInTheme.accent)
        .toolbarBackground(ChipInTheme.surfaceTabBar.opacity(0.92), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environment(auth)
        }
        .task {
            await sync.startListening {
                NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            }
        }
    }
}
