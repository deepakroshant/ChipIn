import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) var auth
    @State private var isSigningIn = false
    @State private var localError: String?

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Chip In")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Split expenses with friends")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#F97316"))
                }

                Spacer()

                if isSigningIn {
                    ProgressView()
                        .tint(Color(hex: "#F97316"))
                        .padding(.bottom, 8)
                }

                if let msg = localError ?? auth.lastError {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleAppleResult(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .padding(.horizontal, 32)
                .disabled(isSigningIn)

                #if DEBUG
                Button {
                    Task { await handleGuestSignIn() }
                } label: {
                    Text("Try as guest (no Apple — dev only)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "#F97316"))
                }
                .disabled(isSigningIn)
                .padding(.top, 8)
                #endif

                if let msg = localError ?? auth.lastError {
                    Button("Dismiss") {
                        localError = nil
                        auth.lastError = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                    .frame(height: 48)
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        localError = nil
        auth.lastError = nil
        switch result {
        case .failure(let error):
            localError = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                localError = "Unexpected credential type."
                return
            }
            isSigningIn = true
            defer { isSigningIn = false }
            do {
                try await auth.signInWithApple(credential: credential)
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func handleGuestSignIn() async {
        localError = nil
        auth.lastError = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await auth.signInAnonymouslyForDevelopment()
        } catch {
            localError =
                "\(error.localizedDescription)\n\nIf this fails: Supabase → Authentication → Providers → enable **Anonymous**."
        }
    }
}
