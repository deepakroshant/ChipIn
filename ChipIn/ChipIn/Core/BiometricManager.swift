import LocalAuthentication
import SwiftUI

@MainActor
@Observable
class BiometricManager {
    var isUnlocked = false
    var error: String?

    private var isAuthenticating = false

    init() {
        if !UserDefaults.standard.bool(forKey: "biometricEnabled") {
            isUnlocked = true
        }
    }

    /// Reads the same key as `@AppStorage("biometricEnabled")` / Profile toggle.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometricEnabled")
    }

    /// Primary button label: Face ID vs Touch ID vs generic unlock.
    func unlockButtonTitle() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default: return "Unlock ChipIn"
        }
    }

    func authenticate() async {
        guard isEnabled else {
            isUnlocked = true
            error = nil
            return
        }
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        error = nil
        let context = LAContext()

        // Prefer device owner auth: Face ID / Touch ID when available, else device passcode.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            isUnlocked = true
            error = "No passcode or biometrics on this device. Turn off App Lock in Settings."
            return
        }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock ChipIn"
            )
            isUnlocked = ok
            if !ok { error = "Authentication failed." }
        } catch {
            if let la = error as? LAError, la.code == .userCancel || la.code == .systemCancel {
                isUnlocked = false
                return
            }
            self.error = error.localizedDescription
            isUnlocked = false
        }
    }
}
