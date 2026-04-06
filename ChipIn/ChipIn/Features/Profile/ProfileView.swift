import SwiftUI
import Supabase
import PostgREST
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) var auth
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var pushCustomSoundEnabled = UserDefaults.standard.object(forKey: "pushCustomSoundEnabled") as? Bool ?? true
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("hideBalances") private var hideBalances = false
    @AppStorage("accentColor") private var accentColorHex = "#F97316"
    @AppStorage("forceDarkMode") private var forceDarkMode = true
    @State private var interacContact = ""
    @State private var username = ""
    @State private var isSavingInterac = false
    @State private var showQR = false
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarUIImage: UIImage?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?
    private let avatarService = AvatarService()

    private let accents = ["#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899"]

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarImage
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())

                            PhotosPicker(selection: $selectedAvatar, matching: .images) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(ChipInTheme.accent)
                                    .background(
                                        Circle()
                                            .fill(ChipInTheme.background)
                                            .frame(width: 28, height: 28)
                                    )
                            }
                            .offset(x: 4, y: 4)
                        }

                        if isUploadingAvatar {
                            ProgressView("Uploading…")
                                .font(.caption).tint(ChipInTheme.accent)
                        }
                        if let err = avatarError {
                            Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
                        }

                        VStack(spacing: 2) {
                            Text(auth.currentUser?.displayName ?? "")
                                .font(.headline).foregroundStyle(ChipInTheme.label)
                            if let u = auth.currentUser?.username, !u.isEmpty {
                                Text("@\(u)")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(ChipInTheme.accent)
                            }
                            Text(auth.currentUser?.email ?? "")
                                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(ChipInTheme.card)
                }
                .onChange(of: selectedAvatar) { _, item in
                    guard let item else { return }
                    Task {
                        isUploadingAvatar = true
                        avatarError = nil
                        defer { isUploadingAvatar = false }
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let img = UIImage(data: data),
                              let userId = auth.currentUser?.id else {
                            avatarError = "Couldn't load photo."
                            return
                        }
                        avatarUIImage = img
                        do {
                            let url = try await avatarService.uploadAvatar(userId: userId, image: img)
                            try await avatarService.saveAvatarURL(userId: userId, url: url)
                            await auth.reloadCurrentUser()
                            selectedAvatar = nil
                        } catch {
                            avatarError = error.localizedDescription
                        }
                    }
                }

                if let userId = auth.currentUser?.id {
                    Section {
                        SpendingPersonalityView(userId: userId)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        Text("Your Spending Personality")
                    }
                }

                // Username
                Section {
                    HStack {
                        Label("Username", systemImage: "at")
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                        TextField("yourname", text: $username)
                            .foregroundStyle(ChipInTheme.label)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { saveUsername() }
                    }
                    .listRowBackground(ChipInTheme.card)
                } header: {
                    Text("Username")
                } footer: {
                    Text("Friends can find you by @username")
                }

                // Add Friend by QR
                Section {
                    Button {
                        showQR = true
                    } label: {
                        Label("Add Friend by QR Code", systemImage: "qrcode")
                            .foregroundStyle(ChipInTheme.accent)
                    }
                    .listRowBackground(ChipInTheme.card)
                } footer: {
                    Text("Show your QR to a friend or paste theirs to look them up")
                }
                .sheet(isPresented: $showQR) {
                    if let user = auth.currentUser {
                        FriendQRView(userId: user.id, displayName: user.displayName)
                    }
                }

                // Interac e-Transfer
                Section {
                    HStack {
                        Label("Interac Contact", systemImage: "envelope.fill")
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                        TextField("Email or phone", text: $interacContact)
                            .foregroundStyle(ChipInTheme.label)
                            .multilineTextAlignment(.trailing)
                            .onSubmit { saveInteracContact() }
                    }
                    .listRowBackground(ChipInTheme.card)
                } header: {
                    Text("Interac e-Transfer")
                } footer: {
                    Text("Shown to group members when they settle up with you")
                }

                // Appearance
                Section {
                    Toggle(isOn: $forceDarkMode) {
                        Label("Force Dark Mode", systemImage: "moon.fill")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(ChipInTheme.accent)
                    .listRowBackground(ChipInTheme.card)

                    accentColourRow
                } header: {
                    Text("Appearance")
                }

                // Privacy & Security
                Section {
                    Toggle(isOn: $biometricEnabled) {
                        Label("Face ID / Touch ID Lock", systemImage: "faceid")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(ChipInTheme.accent)
                    .listRowBackground(ChipInTheme.card)

                    Toggle(isOn: $hideBalances) {
                        Label("Hide Balances", systemImage: "eye.slash")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(ChipInTheme.accent)
                    .listRowBackground(ChipInTheme.card)
                } header: {
                    Text("Privacy & Security")
                }

                // Sounds & Haptics
                Section {
                    Toggle(isOn: $soundEnabled) {
                        Label("In-app sounds", systemImage: "speaker.wave.2.fill")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(ChipInTheme.accent)
                    .listRowBackground(ChipInTheme.card)

                    Toggle(isOn: $pushCustomSoundEnabled) {
                        Label("Custom push notification sounds", systemImage: "bell.badge.fill")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(ChipInTheme.accent)
                    .listRowBackground(ChipInTheme.card)
                    .onChange(of: pushCustomSoundEnabled) { _, val in
                        UserDefaults.standard.set(val, forKey: "pushCustomSoundEnabled")
                        Task { await savePushCustomSoundPreference(val) }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preview notification tones")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                        HStack(spacing: 10) {
                            Button("Owed") {
                                SoundService.shared.play(.moneyOut, haptic: .light)
                            }
                            .buttonStyle(.bordered)
                            .tint(ChipInTheme.accent)

                            Button("Gained") {
                                SoundService.shared.play(.moneyIn, haptic: .light)
                            }
                            .buttonStyle(.bordered)
                            .tint(ChipInTheme.accent)
                        }
                    }
                    .listRowBackground(ChipInTheme.card)
                } header: {
                    Text("Sounds & Haptics")
                } footer: {
                    Text("In-app plays when you save an expense on this device. Push sounds apply on other devices when someone else affects your balance — turn off custom push sounds to use Apple’s default tone. Remote push does not work in Simulator (use a real iPhone). For Simulator audio, enable output in I/O → Audio and use Preview tones above.")
                }

                // Widgets
                Section {
                    Label("Configure Widgets", systemImage: "square.grid.2x2")
                        .foregroundStyle(ChipInTheme.label)
                        .listRowBackground(ChipInTheme.card)
                } header: {
                    Text("Widgets")
                } footer: {
                    Text("Long-press your Home Screen to add Chip In widgets")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version").foregroundStyle(ChipInTheme.secondaryLabel)
                        Spacer()
                        Text("1.0.0").foregroundStyle(ChipInTheme.secondaryLabel)
                    }
                    .listRowBackground(ChipInTheme.card)
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        Task { try? await auth.signOut() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                    .listRowBackground(ChipInTheme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ChipInTheme.background)
            .navigationTitle("Profile")
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                interacContact = auth.currentUser?.interacContact ?? ""
                username = auth.currentUser?.username ?? ""
                pushCustomSoundEnabled = auth.currentUser?.pushCustomSoundEnabled ?? true
            }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let img = avatarUIImage {
            Image(uiImage: img)
                .resizable().scaledToFill()
        } else if let urlStr = auth.currentUser?.avatarURL,
                  let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Color(hex: accentColorHex).opacity(0.2))
                        .overlay(
                            Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                                .font(.title2).bold()
                                .foregroundStyle(Color(hex: accentColorHex))
                        )
                }
            }
        } else {
            Circle()
                .fill(Color(hex: accentColorHex).opacity(0.2))
                .overlay(
                    Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                        .font(.title2).bold()
                        .foregroundStyle(Color(hex: accentColorHex))
                )
        }
    }

    private func saveUsername() {
        guard let id = auth.currentUser?.id else { return }
        let clean = username.lowercased().replacingOccurrences(of: "@", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        Task {
            _ = try? await supabase
                .from("users")
                .update(["username": clean])
                .eq("id", value: id)
                .execute()
        }
    }

    private func saveInteracContact() {
        guard let id = auth.currentUser?.id else { return }
        Task {
            _ = try? await supabase
                .from("users")
                .update(["interac_contact": interacContact])
                .eq("id", value: id)
                .execute()
        }
    }

    private func savePushCustomSoundPreference(_ enabled: Bool) async {
        guard let id = auth.currentUser?.id else { return }
        struct Row: Encodable { let push_custom_sound_enabled: Bool }
        do {
            try await supabase
                .from("users")
                .update(Row(push_custom_sound_enabled: enabled))
                .eq("id", value: id)
                .execute()
        } catch {
            // Preference sync is best-effort; UI already updated locally.
        }
        await auth.reloadCurrentUser()
    }

    private var accentColourRow: some View {
        HStack {
            Text("Accent Colour")
                .foregroundStyle(ChipInTheme.label)
            Spacer()
            HStack(spacing: 12) {
                ForEach(accents, id: \.self) { hex in
                    accentColourCircle(hex: hex)
                }
            }
        }
        .listRowBackground(ChipInTheme.card)
    }

    private func accentColourCircle(hex: String) -> some View {
        let isSelected = accentColorHex == hex
        return Circle()
            .fill(Color(hex: hex))
            .frame(width: 26, height: 26)
            .overlay(
                Circle().stroke(
                    isSelected ? Color.white.opacity(0.9) : ChipInTheme.elevated,
                    lineWidth: isSelected ? 2.5 : 1
                )
            )
            .onTapGesture {
                accentColorHex = hex
            }
    }
}
