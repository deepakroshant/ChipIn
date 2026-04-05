import SwiftUI
import Supabase
import PostgREST
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) var auth
    @State private var soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
    @State private var biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
    @State private var hideBalances = UserDefaults.standard.bool(forKey: "hideBalances")
    @State private var selectedAccent = UserDefaults.standard.string(forKey: "accentColor") ?? "#F97316"
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
                        } catch {
                            avatarError = error.localizedDescription
                        }
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
                Section("Appearance") {
                    HStack {
                        Text("Accent Colour")
                            .foregroundStyle(ChipInTheme.label)
                        Spacer()
                        HStack(spacing: 12) {
                            ForEach(accents, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle().stroke(.white, lineWidth: selectedAccent == hex ? 2.5 : 0)
                                    )
                                    .onTapGesture {
                                        selectedAccent = hex
                                        UserDefaults.standard.set(hex, forKey: "accentColor")
                                    }
                            }
                        }
                    }
                    .listRowBackground(ChipInTheme.card)
                }

                // Privacy & Security
                Section("Privacy & Security") {
                    Toggle(isOn: $biometricEnabled) {
                        Label("Face ID / Touch ID Lock", systemImage: "faceid")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(Color(hex: selectedAccent))
                    .listRowBackground(ChipInTheme.card)
                    .onChange(of: biometricEnabled) { _, val in
                        UserDefaults.standard.set(val, forKey: "biometricEnabled")
                    }

                    Toggle(isOn: $hideBalances) {
                        Label("Hide Balances", systemImage: "eye.slash")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(Color(hex: selectedAccent))
                    .listRowBackground(ChipInTheme.card)
                    .onChange(of: hideBalances) { _, val in
                        UserDefaults.standard.set(val, forKey: "hideBalances")
                    }
                }

                // Sounds & Haptics
                Section("Sounds & Haptics") {
                    Toggle(isOn: $soundEnabled) {
                        Label("Custom Sounds", systemImage: "speaker.wave.2.fill")
                            .foregroundStyle(ChipInTheme.label)
                    }
                    .tint(Color(hex: selectedAccent))
                    .listRowBackground(ChipInTheme.card)
                    .onChange(of: soundEnabled) { _, val in
                        UserDefaults.standard.set(val, forKey: "soundEnabled")
                    }
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
                        .fill(Color(hex: selectedAccent).opacity(0.2))
                        .overlay(
                            Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                                .font(.title2).bold()
                                .foregroundStyle(Color(hex: selectedAccent))
                        )
                }
            }
        } else {
            Circle()
                .fill(Color(hex: selectedAccent).opacity(0.2))
                .overlay(
                    Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                        .font(.title2).bold()
                        .foregroundStyle(Color(hex: selectedAccent))
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
            try? await supabase
                .from("users")
                .update(["interac_contact": interacContact])
                .eq("id", value: id)
                .execute()
        }
    }
}
