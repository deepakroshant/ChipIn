import SwiftUI
import Supabase

@main
struct ChipInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var auth = AuthManager()
    @State private var biometric = BiometricManager()
    @State private var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")

    init() {
        UserDefaults.standard.register(defaults: ["soundEnabled": true])
        ChipInNavigationAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if biometric.isEnabled && !biometric.isUnlocked {
                    lockScreen
                } else {
                    SwiftUI.Group {
                        if auth.isLoading {
                            ZStack {
                                ChipInTheme.background.ignoresSafeArea()
                                ProgressView()
                                    .tint(ChipInTheme.accent)
                                    .scaleEffect(1.5)
                            }
                        } else if auth.isAuthenticated {
                            if !onboardingComplete {
                                OnboardingView(isComplete: $onboardingComplete)
                            } else {
                                ContentView()
                            }
                        } else {
                            AuthView()
                        }
                    }
                    .environment(auth)
                }
            }
            .preferredColorScheme(.dark)
            .task { await auth.initialize() }
            .task { await biometric.authenticate() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                if biometric.isEnabled { biometric.isUnlocked = false }
            }
            .onOpenURL { url in
                guard url.scheme == "chipin",
                      url.host == "join",
                      let inviteId = url.pathComponents.last,
                      let uuid = UUID(uuidString: inviteId),
                      let userId = auth.currentUser?.id else { return }
                Task {
                    struct Invite: Decodable { let group_id: UUID; let expires_at: Date }
                    guard let invite: Invite = try? await supabase
                        .from("group_invites")
                        .select()
                        .eq("id", value: uuid)
                        .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                        .single()
                        .execute()
                        .value else { return }
                    try? await supabase.from("group_members").insert([
                        "group_id": invite.group_id.uuidString,
                        "user_id": userId.uuidString,
                        "role": "member"
                    ]).execute()
                    NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
                }
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("⚡️").font(.system(size: 64))
                Text("ChipIn").font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(ChipInTheme.accent)
                Button {
                    Task { await biometric.authenticate() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .frame(maxWidth: .infinity).padding()
                        .background(ChipInTheme.accent)
                        .foregroundStyle(.black).fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                if let err = biometric.error {
                    Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
                }
            }
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
