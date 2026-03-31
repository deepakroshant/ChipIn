import SwiftUI
import Supabase
import PostgREST

struct ProfileView: View {
    @Environment(AuthManager.self) var auth
    @State private var soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
    @State private var biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
    @State private var hideBalances = UserDefaults.standard.bool(forKey: "hideBalances")
    @State private var selectedAccent = UserDefaults.standard.string(forKey: "accentColor") ?? "#F97316"
    @State private var interacContact = ""
    @State private var isSavingInterac = false

    private let accents = ["#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899"]

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: selectedAccent).opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(auth.currentUser?.name.prefix(1).uppercased() ?? "?")
                                    .font(.title2).bold()
                                    .foregroundStyle(Color(hex: selectedAccent))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.currentUser?.name ?? "")
                                .font(.headline).foregroundStyle(ChipInTheme.label)
                            Text(auth.currentUser?.email ?? "")
                                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                    }
                    .listRowBackground(ChipInTheme.card)
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
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                interacContact = auth.currentUser?.interacContact ?? ""
            }
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
