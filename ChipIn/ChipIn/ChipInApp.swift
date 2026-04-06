import SwiftUI
import Supabase

@main
struct ChipInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var auth = AuthManager()
    @State private var biometric = BiometricManager()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("forceDarkMode") private var forceDark = true
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    /// Binds SwiftUI to accent changes from Profile so `ChipInTheme.accent` refreshes everywhere.
    @AppStorage("accentColor") private var accentColorHex = "#F97316"

    init() {
        UserDefaults.standard.register(defaults: [
            "soundEnabled": true,
            "pushCustomSoundEnabled": true,
            "forceDarkMode": true,
            "biometricEnabled": false,
            "hideBalances": false,
            "onboardingComplete": false,
            "accentColor": "#F97316",
        ])
        ChipInNavigationAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Text(verbatim: accentColorHex)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                if biometricEnabled && !biometric.isUnlocked {
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
            .preferredColorScheme(forceDark ? .dark : nil)
            .onChange(of: accentColorHex) { _, _ in
                ChipInNavigationAppearance.apply()
            }
            .task { await auth.initialize() }
            .onChange(of: biometricEnabled) { _, enabled in
                biometric.isUnlocked = !enabled
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                if biometricEnabled { biometric.isUnlocked = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if biometricEnabled && !biometric.isUnlocked {
                    Task { await biometric.authenticate() }
                }
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
                    _ = try? await supabase.from("group_members").insert([
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
                Image("ChipInLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                Text("ChipIn").font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(ChipInTheme.accent)
                Button {
                    Task { await biometric.authenticate() }
                } label: {
                    Label(biometric.unlockButtonTitle(), systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(ChipInTheme.ctaGradient)
                        .foregroundStyle(ChipInTheme.onPrimary).fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 40)
                if let err = biometric.error {
                    Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
                }
            }
            .onAppear {
                Task { await biometric.authenticate() }
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
