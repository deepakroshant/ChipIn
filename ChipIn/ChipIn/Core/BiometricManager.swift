import LocalAuthentication
import SwiftUI

@MainActor
@Observable
class BiometricManager {
    var isUnlocked = false
    var error: String?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometricEnabled")
    }

    func authenticate() async {
        guard isEnabled else { isUnlocked = true; return }
        let context = LAContext()
        var laError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &laError) else {
            isUnlocked = true
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock ChipIn"
            )
            isUnlocked = success
            if !success { error = "Authentication failed." }
        } catch {
            self.error = error.localizedDescription
            isUnlocked = false
        }
    }
}
