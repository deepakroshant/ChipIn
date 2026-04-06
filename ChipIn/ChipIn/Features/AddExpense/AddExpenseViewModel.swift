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
    var context: AddExpenseContext = .friends
    var selectedGroupId: UUID?
    var selectedUserIds: [UUID] = []
    var isRecurring = false
    var recurrenceInterval = "monthly"
    var note = ""
    var isSubmitting = false
    var error: String?
    var showReceiptScanner = false
    var wasAutoDetected = false
    var parsedReceipt: ParsedReceipt?
    var friendEmailLookup = ""

    /// Who actually paid — nil means the current signed-in user.
    var paidByOverride: UUID?

    /// Per-person custom values: % for percent, $ for exact, share count for shares.
    var customSplitValues: [UUID: String] = [:]

    /// Optional tax amount added on top (distributed proportionally).
    var taxAmount = ""

    /// Tip amount (added on top, distributed proportionally).
    var tipAmount: Decimal = 0

    var parsedMentionHandle: String?

    private let service = ExpenseService()

    var amountDecimal: Decimal { Decimal(string: amount) ?? 0 }
    var taxDecimal: Decimal { Decimal(string: taxAmount) ?? 0 }
    var totalWithTax: Decimal { amountDecimal + taxDecimal + tipAmount }

    // MARK: - Computed summaries for validation UI

    var percentTotal: Decimal {
        selectedUserIds.reduce(0) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
    }

    var exactTotal: Decimal {
        selectedUserIds.reduce(0) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
    }

    var sharesTotal: Decimal {
        selectedUserIds.reduce(0) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
    }

    /// Fills amount, tax, and tip from a scanned receipt so `totalWithTax` matches subtotal + tax + tip (no double-counting).
    func applyReceiptToAmountFields(_ receipt: ParsedReceipt) {
        amount = Self.formatDecimalForField(receipt.subtotal)
        taxAmount = receipt.tax > 0 ? Self.formatDecimalForField(receipt.tax) : ""
        tipAmount = receipt.tip
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = receipt.suggestedTitle
        }
    }

    /// Clears receipt-driven state when switching back to manual entry.
    func clearReceiptData() {
        parsedReceipt = nil
        if splitType == .byItem {
            splitType = .equal
        }
        tipAmount = 0
        taxAmount = ""
    }

    private static func formatDecimalForField(_ d: Decimal) -> String {
        let v = Double(truncating: NSDecimalNumber(decimal: d))
        return String(format: "%.2f", v)
    }

    // MARK: - Auto-category

    func autoDetectCategory(from title: String) {
        if let detected = CategoryDetector.detect(from: title) {
            category = detected
            wasAutoDetected = true
        } else {
            wasAutoDetected = false
        }
    }

    /// Applies quick-text parsing: if title contains "$20 @sarah" style, auto-fills amount and sets handle search.
    func applyQuickParse(raw: String) -> String {
        let result = QuickTextParser.parse(raw)
        if let a = result.amount, !a.isEmpty, amount.isEmpty {
            amount = a
        }
        parsedMentionHandle = result.mentionedHandle
        if !result.cleanTitle.isEmpty {
            return result.cleanTitle
        }
        return raw
    }

    // MARK: - Participant helpers

    func toggleSplitParticipant(_ id: UUID) {
        if selectedUserIds.count == 1, selectedUserIds.contains(id) { return }
        if let idx = selectedUserIds.firstIndex(of: id) {
            selectedUserIds.remove(at: idx)
        } else {
            selectedUserIds.append(id)
        }
    }

    func ensurePayerSelected(_ paidBy: UUID) {
        if selectedUserIds.isEmpty {
            selectedUserIds = [paidBy]
        } else if !selectedUserIds.contains(paidBy) {
            selectedUserIds.insert(paidBy, at: 0)
        }
    }

    func addUserFromEmailLookup(_ user: AppUser) {
        friendEmailLookup = ""
        if !selectedUserIds.contains(user.id) {
            selectedUserIds.append(user.id)
        }
    }

    // MARK: - Split calculation

    struct SplitError: Error { let message: String }

    private func buildSplits() -> Result<[(userId: UUID, amount: Decimal)], SplitError> {
        let total = totalWithTax
        guard total > 0 else { return .failure(SplitError(message: "Enter a valid amount.")) }
        let ids = selectedUserIds
        guard !ids.isEmpty else { return .failure(SplitError(message: "Select at least one person.")) }

        // Per-line splits only when the user explicitly picks "By Item" and the receipt has lines.
        // Otherwise (Equal, %, exact, shares) we split the grand total — same as manual entry with tax.
        if let receipt = parsedReceipt, splitType == .byItem, !receipt.items.isEmpty {
            return .success(service.calculateItemSplits(receipt: receipt, participantIds: ids))
        }

        switch splitType {
        case .equal:
            return .success(service.calculateEqualSplits(amount: total, userIds: ids))

        case .percent:
            let pctTotal = ids.reduce(Decimal(0)) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
            if abs(pctTotal - 100) > 0.01 {
                return .failure(SplitError(message: "Percentages must add up to 100% (currently \(pctTotal)%)."))
            }
            let splits = ids.map { id -> (userId: UUID, amount: Decimal) in
                let pct = (Decimal(string: customSplitValues[id] ?? "") ?? 0) / 100
                var share = total * pct
                var rounded = Decimal()
                NSDecimalRound(&rounded, &share, 2, .bankers)
                return (id, rounded)
            }
            return .success(splits)

        case .exact:
            let enteredTotal = ids.reduce(Decimal(0)) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
            if abs(enteredTotal - total) > 0.01 {
                return .failure(SplitError(message: "Amounts must add up to \(total) (currently \(enteredTotal))."))
            }
            let splits = ids.map { id -> (userId: UUID, amount: Decimal) in
                let val = Decimal(string: customSplitValues[id] ?? "") ?? 0
                return (id, val)
            }
            return .success(splits)

        case .shares:
            let shareSum = ids.reduce(Decimal(0)) { $0 + (Decimal(string: customSplitValues[$1] ?? "") ?? 0) }
            guard shareSum > 0 else { return .failure(SplitError(message: "Enter share counts for each person.")) }
            let splits = ids.map { id -> (userId: UUID, amount: Decimal) in
                let s = Decimal(string: customSplitValues[id] ?? "") ?? 0
                var share = total * s / shareSum
                var rounded = Decimal()
                NSDecimalRound(&rounded, &share, 2, .bankers)
                return (id, rounded)
            }
            return .success(splits)

        case .byItem:
            return .success(service.calculateEqualSplits(amount: total, userIds: ids))
        }
    }

    // MARK: - Recurring helpers

    private func nextDueDate(from date: Date, interval: String) -> Date? {
        let cal = Calendar.current
        switch interval {
        case "weekly":  return cal.date(byAdding: .weekOfYear, value: 1, to: date)
        case "monthly": return cal.date(byAdding: .month, value: 1, to: date)
        case "yearly":  return cal.date(byAdding: .year, value: 1, to: date)
        default:        return cal.date(byAdding: .month, value: 1, to: date)
        }
    }

    // MARK: - Submit

    func submit(defaultPaidBy: UUID) async -> Bool {
        error = nil
        guard !title.isEmpty, amountDecimal > 0 else {
            error = "Add a title and a valid amount."
            return false
        }

        let paidBy = paidByOverride ?? defaultPaidBy

        if context == .friends {
            guard selectedUserIds.count >= 2 else {
                error = "Pick at least two people."
                return false
            }
        } else {
            guard selectedGroupId != nil else { error = "Choose a group."; return false }
            guard !selectedUserIds.isEmpty else { error = "Select who is in this split."; return false }
        }

        switch buildSplits() {
        case .failure(let splitErr):
            error = splitErr.message
            return false
        case .success(let splits):
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                var expenseItems: [NewExpenseItem] = []
                let useLineItems = (parsedReceipt?.items.isEmpty == false) && splitType == .byItem
                if useLineItems, let receipt = parsedReceipt {
                    expenseItems = receipt.items.compactMap { item in
                        guard let owner = item.assignedTo else { return nil }
                        return NewExpenseItem(name: item.name, price: item.price, taxPortion: item.taxPortion, assignedTo: owner)
                    }
                }
                let gid: UUID? = context == .friends ? nil : selectedGroupId
                let expense = try await service.createExpense(
                    groupId: gid,
                    paidBy: paidBy,
                    title: title,
                    amount: totalWithTax,
                    currency: currency,
                    category: category.rawValue,
                    splitType: useLineItems ? .byItem : splitType,
                    splits: splits,
                    isRecurring: isRecurring,
                    recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                    items: expenseItems
                )
                if isRecurring, let dueDate = nextDueDate(from: Date(), interval: recurrenceInterval) {
                    NotificationManager.shared.scheduleRecurringReminder(
                        expenseTitle: title,
                        dueDate: dueDate,
                        expenseId: expense.id
                    )
                }
                ToastManager.shared.markLocalSave()
                NotificationCenter.default.post(
                    name: .chipInToast,
                    object: nil,
                    userInfo: ["message": "Expense saved"]
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
}
