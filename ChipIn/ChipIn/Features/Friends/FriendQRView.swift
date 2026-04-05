import SwiftUI
import CoreImage.CIFilterBuiltins

struct FriendQRView: View {
    let userId: UUID
    let displayName: String
    @Environment(\.dismiss) var dismiss
    @State private var scanMode = false
    @State private var showScanInput = false
    @State private var scannedCode: String = ""
    @State private var resolvedUser: AppUser?
    @State private var isLooking = false
    @State private var lookupError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 32) {
                    Picker("Mode", selection: $scanMode) {
                        Text("My QR").tag(false)
                        Text("Scan Friend").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)

                    if !scanMode {
                        myQRSection
                    } else {
                        scanSection
                    }

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Add Friend by QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var myQRSection: some View {
        VStack(spacing: 16) {
            Text("Show this to friends")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)

            if let img = generateQR(from: "chipin://add-friend/\(userId.uuidString)") {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Text(displayName)
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)

            Text("chipin://add-friend/\(userId.uuidString)")
                .font(.caption2)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var scanSection: some View {
        VStack(spacing: 20) {
            if let user = resolvedUser {
                VStack(spacing: 12) {
                    Text("✅").font(.system(size: 48))
                    Text("Found \(user.displayName)!")
                        .font(.headline).foregroundStyle(ChipInTheme.label)
                    Text(user.email)
                        .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
                    Text("Add them to a group from the Groups tab to start splitting.")
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Look up another") { resolvedUser = nil; scannedCode = "" }
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.accent)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(ChipInTheme.accent)

                    Text("Paste or type a ChipIn friend code")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                        .multilineTextAlignment(.center)

                    TextField("chipin://add-friend/...", text: $scannedCode)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 32)

                    Button {
                        Task { await resolveCode(scannedCode) }
                    } label: {
                        Text("Look Up")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ChipInTheme.ctaGradient)
                            .foregroundStyle(ChipInTheme.onPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                    .disabled(scannedCode.isEmpty || isLooking)
                }
            }

            if isLooking { ProgressView().tint(ChipInTheme.accent) }
            if let err = lookupError {
                Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
            }
        }
    }

    private func resolveCode(_ code: String) async {
        isLooking = true
        lookupError = nil
        defer { isLooking = false }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let uuidStr = cleaned.components(separatedBy: "chipin://add-friend/").last ?? cleaned
        guard let uuid = UUID(uuidString: uuidStr) else {
            lookupError = "Invalid QR code. Make sure you copied the full link."
            return
        }
        let users: [AppUser] = (try? await supabase
            .from("users").select().eq("id", value: uuid).limit(1).execute().value) ?? []
        if let user = users.first {
            resolvedUser = user
        } else {
            lookupError = "No ChipIn user found with that code."
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
