import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) var auth

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

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        switch result {
                        case .success(let authorization):
                            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                try? await auth.signInWithApple(credential: credential)
                            }
                        case .failure: break
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
