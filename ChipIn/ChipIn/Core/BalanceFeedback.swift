import UIKit

/// Directional toast + SFX when your net position shifts after a sync (someone else edited splits / expenses).
enum BalanceFeedback {
    private static let eps: Decimal = 0.02
    private static var lastEmitAt = Date.distantPast

    @MainActor
    static func emitIfNeeded(deltaOverall: Decimal, deltaPending: Decimal) {
        guard !ToastManager.shared.shouldSuppressBalanceFeedback() else { return }

        let now = Date()
        guard now.timeIntervalSince(lastEmitAt) > 0.85 else { return }
        lastEmitAt = now

        // overallNet ↑ = better for you (they owe you more net). pendingOwed ↑ = you owe more total.
        let gained = deltaOverall > eps || deltaPending < -eps
        let lost = deltaOverall < -eps || deltaPending > eps
        guard gained || lost else { return }

        let message: String
        let dualSound: Bool
        if gained && lost {
            message = "Balances updated"
            dualSound = true
        } else if gained {
            message = "You're owed more"
            dualSound = false
        } else {
            message = "You owe more"
            dualSound = false
        }

        let isActive = UIApplication.shared.applicationState == .active

        if isActive {
            ToastManager.shared.show(message)
            // Audio only here — haptics clash with keyboard/simulator noise and read as “wrong” feedback.
            if dualSound {
                SoundService.shared.play(.moneyIn, haptic: nil)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    SoundService.shared.play(.moneyOut, haptic: nil)
                }
            } else if gained {
                SoundService.shared.play(.moneyIn, haptic: nil)
            } else {
                SoundService.shared.play(.moneyOut, haptic: nil)
            }
        } else {
            let tone: Bool? = dualSound ? nil : gained
            NotificationManager.shared.scheduleBalancePing(title: "ChipIn", body: message, positive: tone)
        }
    }
}
