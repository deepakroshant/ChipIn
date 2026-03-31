import SwiftUI
import Supabase
import PostgREST
import Auth
import AuthenticationServices

@MainActor
@Observable
class AuthManager {
    var currentUser: AppUser?
    var isAuthenticated = false
    var isLoading = true
    /// Last error for UI (sign-in failures, missing profile, etc.)
    var lastError: String?

    func initialize() async {
        do {
            let session = try await supabase.auth.session
            try await ensureUserProfile(for: session.user)
            await loadUser(id: session.user.id)
        } catch {
            isAuthenticated = false
        }
        isLoading = false

        Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    if let session {
                        try? await ensureUserProfile(for: session.user)
                        await loadUser(id: session.user.id)
                    }
                case .signedOut:
                    currentUser = nil
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    private func loadUser(id: UUID) async {
        do {
            let user: AppUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            currentUser = user
            isAuthenticated = true
            lastError = nil
        } catch {
            currentUser = nil
            isAuthenticated = false
            lastError = "Could not load profile: \(error.localizedDescription)"
        }
    }

    /// Ensures `public.users` row exists — trigger handles insert, this just updates metadata.
    private func ensureUserProfile(for user: User) async throws {
        let email: String = {
            if let e = user.email, !e.isEmpty { return e }
            if user.isAnonymous { return "guest-\(user.id.uuidString.prefix(8))@local.dev" }
            return "user-\(user.id.uuidString.prefix(8))@local.invalid"
        }()

        var name = "User"
        if user.isAnonymous { name = "Guest" }
        if let full = user.userMetadata["full_name"], case .string(let s) = full, !s.isEmpty { name = s }

        struct UserRow: Encodable { let id: String; let name: String; let email: String }

        // Try upsert; if trigger already created row this is a no-op conflict.
        _ = try? await supabase
            .from("users")
            .upsert(UserRow(id: user.id.uuidString, name: name, email: email), onConflict: "id")
            .execute()
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        lastError = nil
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: tokenString)
        )

        let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        let name = appleName.isEmpty ? "Apple User" : appleName
        var email = session.user.email ?? ""
        if email.isEmpty {
            email = "\(session.user.id.uuidString.prefix(8))@apple.private"
        }

        struct UserRow: Encodable {
            let id: String
            let name: String
            let email: String
        }

        try await supabase
            .from("users")
            .upsert(UserRow(id: session.user.id.uuidString, name: name, email: email))
            .execute()

        await loadUser(id: session.user.id)
    }

    func signUpWithEmail(email: String, password: String, name: String) async throws {
        lastError = nil
        let session = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": AnyJSON.string(name.isEmpty ? "User" : name)]
        )
        // Trigger handle_new_user creates public.users row automatically.
        // Update name in case trigger ran before metadata propagated.
        if !name.isEmpty {
            _ = try? await supabase
                .from("users")
                .update(["name": name])
                .eq("id", value: session.user.id.uuidString)
                .execute()
        }
        await loadUser(id: session.user.id)
    }

    func signInWithEmail(email: String, password: String) async throws {
        lastError = nil
        let session = try await supabase.auth.signIn(email: email, password: password)
        await loadUser(id: session.user.id)
    }

    /// Free local testing: no Apple Developer account. Enable **Anonymous** in Supabase → Authentication → Providers.
    func signInAnonymouslyForDevelopment() async throws {
        lastError = nil
        let session = try await supabase.auth.signInAnonymously()
        try await ensureUserProfile(for: session.user)
        await loadUser(id: session.user.id)
    }

    func signOut() async throws {
        lastError = nil
        try await supabase.auth.signOut()
    }

    enum AuthError: Error {
        case invalidCredential
    }
}
