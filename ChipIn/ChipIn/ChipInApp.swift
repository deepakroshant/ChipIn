import SwiftUI

@main
struct ChipInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var auth = AuthManager()

    init() {
        UserDefaults.standard.register(defaults: ["soundEnabled": true])
    }

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                if auth.isLoading {
                    ProgressView()
                        .tint(Color(hex: "#F97316"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: "#0A0A0A"))
                } else if auth.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .environment(auth)
            .task { await auth.initialize() }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
