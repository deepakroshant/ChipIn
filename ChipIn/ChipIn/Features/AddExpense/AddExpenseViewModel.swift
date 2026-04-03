import SwiftUI

enum AddExpenseContext: String, CaseIterable {
    case friends = "Friends"
    case group = "Group"
}

@MainActor
@Observable
class AddExpenseViewModel {
    var title = ""
    var amount = ""
    var currency = "CAD"
    var category = ExpenseCategory.food
    var splitType = SplitType.equal
    /// Group expense vs personal/friends split.
    var context: AddExpenseContext = .friends
    var selectedGroupId: UUID?
    var selectedUserIds: [UUID] = []
    var isRecurring = false
    var recurrenceInterval = "monthly"
    var note = ""
    var isSubmitting = false
    var error: String?
    var showReceiptScanner = false
    var parsedReceipt: ParsedReceipt?
    /// Look up another ChipIn user by email (must exist in Supabase `users`).
    var friendEmailLookup = ""

    private let service = ExpenseService()

    var amountDecimal: Decimal {
        Decimal(string: amount) ?? 0
    }

    func toggleSplitParticipant(_ id: UUID) {
        if selectedUserIds.count == 1, selectedUserIds.contains(id) { return }
        if let idx = selectedUserIds.firstIndex(of: id) {
            selectedUserIds.remove(at: idx)
        } else {
            selectedUserIds.append(id)
        }
    }

    /// After loading friend suggestions, ensure you’re selected so user can add others.
    func ensurePayerSelected(_ paidBy: UUID) {
        if selectedUserIds.isEmpty {
            selectedUserIds = [paidBy]
        } else if !selectedUserIds.contains(paidBy) {
            selectedUserIds.insert(paidBy, at: 0)
        }
    }

    func addUserFromEmailLookup(_ user: AppUser) {
        friendEmailLookup = ""
        if selectedUserIds.contains(user.id) { return }
        if !selectedUserIds.contains(user.id) {
            selectedUserIds.append(user.id)
        }
    }

    func submit(paidBy: UUID) async -> Bool {
        error = nil
        guard !title.isEmpty, amountDecimal > 0 else {
            error = "Add a title and a valid amount."
            return false
        }

        if context == .friends {
            guard selectedUserIds.count >= 2 else {
                error = "Pick at least two people."
                return false
            }
            guard selectedUserIds.contains(paidBy) else {
                error = "Include yourself in the split (tap your name)."
                return false
            }
        } else {
            guard selectedGroupId != nil else { error = "Choose a group."; return false }
            guard !selectedUserIds.isEmpty else { error = "Select who is in this split."; return false }
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let splits: [(userId: UUID, amount: Decimal)]
            var expenseItems: [NewExpenseItem] = []

            if let receipt = parsedReceipt {
                splits = service.calculateItemSplits(receipt: receipt, participantIds: selectedUserIds)
                expenseItems = receipt.items.compactMap { item in
                    guard let owner = item.assignedTo else { return nil }
                    return NewExpenseItem(name: item.name, price: item.price, taxPortion: item.taxPortion, assignedTo: owner)
                }
            } else {
                splits = service.calculateEqualSplits(amount: amountDecimal, userIds: selectedUserIds)
            }

            let gid: UUID? = context == .friends ? nil : selectedGroupId
            try await service.createExpense(
                groupId: gid,
                paidBy: paidBy,
                title: title,
                amount: amountDecimal,
                currency: currency,
                category: category.rawValue,
                splitType: parsedReceipt != nil ? .byItem : splitType,
                splits: splits,
                isRecurring: isRecurring,
                recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                items: expenseItems
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
