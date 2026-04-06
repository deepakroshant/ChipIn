import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @State private var sync = SyncManager()
    @State private var lastForegroundRefresh = Date.distantPast
    @Environment(AuthManager.self) var auth
    @Bindable private var toast = ToastManager.shared
    /// Keeps TabView `.tint` and the tab bar in sync when Profile accent changes (UIKit appearance alone can lag).
    @AppStorage("accentColor") private var accentColorHex = "#F97316"

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
        .tint(Color(hex: accentColorHex))
        .toolbarBackground(ChipInTheme.surfaceTabBar.opacity(0.92), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onChange(of: accentColorHex) { _, _ in
            ChipInNavigationAppearance.apply()
        }
        .overlay(alignment: .top) {
            if toast.isVisible, let msg = toast.message {
                ToastBannerView(text: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: toast.isVisible)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environment(auth)
        }
        .task {
            if auth.isAuthenticated {
                await NotificationManager.shared.flushPendingAPNSTokenIfNeeded()
                _ = await NotificationManager.shared.requestPermission()
            }
            await sync.startListening {
                NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chipInToast)) { note in
            guard let msg = note.userInfo?["message"] as? String else { return }
            ToastManager.shared.show(msg)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard auth.isAuthenticated else { return }
            let now = Date()
            guard now.timeIntervalSince(lastForegroundRefresh) > 1.2 else { return }
            lastForegroundRefresh = now
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
        }
    }
}
