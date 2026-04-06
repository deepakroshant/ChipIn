import SwiftUI

@MainActor
@Observable
class SettleUpViewModel {
    var isSettled = false
    var isLoading = false
    private let service = SettlementService()

    func copyAmount(_ amount: Decimal) {
        let formatted = NSDecimalNumber(decimal: amount).stringValue
        UIPasteboard.general.string = formatted
    }

    func openBank(_ bank: BankApp) {
        service.openBankApp(bank)
    }

    func markAsSettled(fromUserId: UUID, toUserId: UUID, amount: Decimal, groupId: UUID?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.settle(fromUserId: fromUserId, toUserId: toUserId, amount: amount, groupId: groupId, method: "interac")
            ToastManager.shared.markLocalSave()
            NotificationCenter.default.post(
                name: .chipInToast,
                object: nil,
                userInfo: ["message": "Marked as settled"]
            )
            SoundService.shared.play(.settled, haptic: .heavy)
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            isSettled = true
        } catch {
            print("Settlement error: \(error)")
        }
    }
}
