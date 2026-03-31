import SwiftUI

@MainActor
@Observable
class AddExpenseViewModel {
    var title = ""
    var amount = ""
    var currency = "CAD"
    var category = ExpenseCategory.food
    var splitType = SplitType.equal
    var selectedGroupId: UUID?
    var selectedUserIds: [UUID] = []
    var isRecurring = false
    var recurrenceInterval = "monthly"
    var note = ""
    var isSubmitting = false
    var error: String?
    var showReceiptScanner = false
    var parsedReceipt: ParsedReceipt?

    private let service = ExpenseService()

    var amountDecimal: Decimal {
        Decimal(string: amount) ?? 0
    }

    func submit(paidBy: UUID) async -> Bool {
        guard !title.isEmpty, amountDecimal > 0, let groupId = selectedGroupId, !selectedUserIds.isEmpty else {
            error = "Please fill in all required fields"
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let splits = service.calculateEqualSplits(amount: amountDecimal, userIds: selectedUserIds)
            try await service.createExpense(
                groupId: groupId,
                paidBy: paidBy,
                title: title,
                amount: amountDecimal,
                currency: currency,
                category: category.rawValue,
                splitType: splitType,
                splits: splits,
                isRecurring: isRecurring,
                recurrenceInterval: isRecurring ? recurrenceInterval : nil
            )
            SoundService.shared.play(.expenseAdd, haptic: .light)
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
