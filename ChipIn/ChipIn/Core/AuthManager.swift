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

    func initialize() async {
        do {
            let session = try await supabase.auth.session
            await loadUser(id: session.user.id)
        } catch {
            isAuthenticated = false
        }
        isLoading = false

        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let session { await loadUser(id: session.user.id) }
            case .signedOut:
                currentUser = nil
                isAuthenticated = false
            default: break
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
        } catch {
            isAuthenticated = false
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: tokenString)
        )
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        if !name.isEmpty {
            try await supabase.from("users").upsert([
                "id": session.user.id.uuidString,
                "name": name,
                "email": session.user.email ?? ""
            ]).execute()
        }
        await loadUser(id: session.user.id)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    enum AuthError: Error {
        case invalidCredential
    }
}
