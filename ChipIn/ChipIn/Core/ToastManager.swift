import SwiftUI

/// In-app banner toasts (foreground). Remote sync is debounced so it doesn’t stack on top of “Expense saved”.
@Observable @MainActor
final class ToastManager {
    static let shared = ToastManager()

    var message: String?
    var isVisible = false

    private var hideTask: Task<Void, Never>?
    private var lastLocalSaveAt = Date.distantPast

    private init() {}

    /// Call when this device just saved an expense — suppresses redundant “Balances updated” for a few seconds.
    func markLocalSave() {
        lastLocalSaveAt = Date()
    }

    /// Skip balance sound/toast right after your own save (Realtime still fires for the same write).
    func shouldSuppressBalanceFeedback() -> Bool {
        Date().timeIntervalSince(lastLocalSaveAt) < 3
    }

    func show(_ text: String, duration: TimeInterval = 2.8) {
        message = text
        isVisible = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                isVisible = false
                message = nil
            }
        }
    }

}
