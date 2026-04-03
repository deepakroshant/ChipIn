import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) var auth
    @State private var isSigningIn = false
    @State private var localError: String?
    @State private var successMessage: String?
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var formAppeared = false

    var body: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 52)

                    // Hero
                    VStack(spacing: 10) {
                        Text("⚡️")
                            .font(.system(size: 56))
                        Text("ChipIn")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(ChipInTheme.accentGradient)
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                            .animation(ChipInTheme.easeDefault, value: isSignUp)
                    }

                    // Form card
                    VStack(spacing: 12) {
                        if isSignUp {
                            StyledTextField(placeholder: "Your name", text: $name, icon: "person.fill")
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        StyledTextField(placeholder: "Email", text: $email, icon: "envelope.fill")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        StyledTextField(placeholder: "Password (6+ chars)", text: $password, icon: "lock.fill", isSecure: true)

                        // Inline feedback
                        if let msg = successMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ChipInTheme.success)
                                Text(msg)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ChipInTheme.success)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        } else if let err = localError ?? auth.lastError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(ChipInTheme.danger)
                                    .padding(.top, 1)
                                Text(friendlyError(err))
                                    .font(.subheadline)
                                    .foregroundStyle(ChipInTheme.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 4)
                        }

                        // Primary CTA
                        Button {
                            Task { await handleEmailAuth() }
                        } label: {
                            primaryButtonLabel
                        }
                        .disabled(isSigningIn || email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))
                        .animation(ChipInTheme.spring, value: isSigningIn)

                        // Toggle sign-in / sign-up
                        Button {
                            withAnimation(ChipInTheme.spring) {
                                isSignUp.toggle()
                                localError = nil
                                successMessage = nil
                                auth.lastError = nil
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account?  **Sign in**" : "New here?  **Create account**")
                                .font(.subheadline)
                                .foregroundStyle(ChipInTheme.accent)
                        }
                    }
                    .padding(20)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)

                    // Divider
                    HStack {
                        Rectangle().fill(ChipInTheme.elevated).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(ChipInTheme.tertiaryLabel).padding(.horizontal, 8)
                        Rectangle().fill(ChipInTheme.elevated).frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    .padding(.horizontal, 24)
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
                .opacity(formAppeared ? 1 : 0)
                .offset(y: formAppeared ? 0 : 24)
            }
        }
        .onAppear {
            withAnimation(ChipInTheme.spring.delay(0.1)) { formAppeared = true }
        }
    }

    @ViewBuilder
    private var primaryButtonLabel: some View {
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
        .background(ChipInTheme.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
    }

    // Map raw Supabase / network errors to Gen-Z friendly messages
    private func friendlyError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("user already registered") || lower.contains("already been registered") || lower.contains("email address is already") {
            return "That email is already registered. Try signing in instead."
        }
        if lower.contains("invalid login credentials") || lower.contains("invalid email or password") || lower.contains("wrong password") {
            return "Wrong email or password. Double-check and try again."
        }
        if lower.contains("email not confirmed") {
            return "Check your inbox and confirm your email first."
        }
        if lower.contains("password should be at least") || lower.contains("password is too short") {
            return "Password needs to be at least 6 characters."
        }
        if lower.contains("rate limit") || lower.contains("too many requests") {
            return "Too many attempts. Wait a moment then try again."
        }
        if lower.contains("network") || lower.contains("timeout") || lower.contains("offline") {
            return "No connection. Check your internet and retry."
        }
        return raw
    }

    private func handleEmailAuth() async {
        localError = nil
        successMessage = nil
        auth.lastError = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            if isSignUp {
                try await auth.signUpWithEmail(email: email, password: password, name: name)
                successMessage = "Account created! Welcome to ChipIn 🎉"
            } else {
                try await auth.signInWithEmail(email: email, password: password)
            }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        localError = nil
        successMessage = nil
        auth.lastError = nil
        switch result {
        case .failure(let error):
            if (error as NSError).code != 1001 { // ignore user cancel
                localError = error.localizedDescription
            }
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
        successMessage = nil
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
    var icon: String = "textformat"
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
                .frame(width: 18)
            ZStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
        }
        .padding(14)
        .background(ChipInTheme.elevated)
        .foregroundStyle(ChipInTheme.label)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius)
                .stroke(ChipInTheme.elevated, lineWidth: 1)
        )
    }
}
