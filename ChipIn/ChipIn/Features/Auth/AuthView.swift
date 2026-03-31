import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) var auth
    @State private var isSigningIn = false
    @State private var localError: String?
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""

    var body: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo / title
                    VStack(spacing: 8) {
                        Text("Chip In")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(ChipInTheme.accent)
                        Text("Split expenses with friends")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                    }

                    Spacer().frame(height: 8)

                    // Email / password form
                    VStack(spacing: 14) {
                        if isSignUp {
                            StyledTextField(placeholder: "Your name", text: $name)
                        }

                        StyledTextField(placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        StyledTextField(placeholder: "Password", text: $password, isSecure: true)

                        if let msg = localError ?? auth.lastError {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(ChipInTheme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }

                        Button {
                            Task { await handleEmailAuth() }
                        } label: {
                            ZStack {
                                if isSigningIn {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(ChipInTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                        }
                        .disabled(isSigningIn || email.isEmpty || password.isEmpty)

                        Button {
                            withAnimation(ChipInTheme.easeDefault) {
                                isSignUp.toggle()
                                localError = nil
                                auth.lastError = nil
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                                .font(.subheadline)
                                .foregroundStyle(ChipInTheme.accent)
                        }
                    }
                    .padding(.horizontal, 28)

                    // Divider
                    HStack {
                        Rectangle().fill(ChipInTheme.elevated).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(ChipInTheme.tertiaryLabel)
                        Rectangle().fill(ChipInTheme.elevated).frame(height: 1)
                    }
                    .padding(.horizontal, 28)

                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    .padding(.horizontal, 28)
                    .disabled(isSigningIn)

                    #if DEBUG
                    Button {
                        Task { await handleGuestSignIn() }
                    } label: {
                        Text("Continue as guest (dev only)")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                    }
                    .disabled(isSigningIn)
                    #endif

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func handleEmailAuth() async {
        localError = nil
        auth.lastError = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            if isSignUp {
                try await auth.signUpWithEmail(email: email, password: password, name: name)
            } else {
                try await auth.signInWithEmail(email: email, password: password)
            }
        } catch {
            localError = error.localizedDescription
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
            localError = "Enable Anonymous auth in Supabase → Authentication → Providers → Anonymous"
        }
    }
}

private struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        ZStack {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(14)
        .background(ChipInTheme.card)
        .foregroundStyle(ChipInTheme.label)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius)
                .stroke(ChipInTheme.elevated, lineWidth: 1)
        )
    }
}
