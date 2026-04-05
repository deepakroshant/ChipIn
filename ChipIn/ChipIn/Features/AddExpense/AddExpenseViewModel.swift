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

    var templates: [ExpenseTemplate] = []
    var showSaveTemplatePrompt = false
    var templateName = ""

    private let service = ExpenseService()
    private let templateService = TemplateService()

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

    // MARK: - Templates

    func loadTemplates(userId: UUID) async {
        templates = (try? await templateService.fetchTemplates(userId: userId)) ?? []
    }

    func applyTemplate(_ template: ExpenseTemplate) {
        title = template.title
        currency = template.currency
        if let cat = ExpenseCategory(rawValue: template.category) {
            category = cat
        }
    }

    func saveCurrentAsTemplate(userId: UUID, name: String) async {
        guard !title.isEmpty else { return }
        try? await templateService.saveTemplate(
            userId: userId, name: name, title: title,
            category: category.rawValue, splitType: splitType.rawValue,
            currency: currency
        )
        await loadTemplates(userId: userId)
    }

    func deleteTemplate(_ template: ExpenseTemplate) async {
        try? await templateService.deleteTemplate(id: template.id)
        templates.removeAll { $0.id == template.id }
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

        // Receipt scans with line items use per-line math (matches `createExpense`’s `splitType: .byItem`).
        // If we used the UI’s Equal/Percent/etc. here, splits would disagree with stored line items.
        if let receipt = parsedReceipt {
            if receipt.items.isEmpty {
                return .success(service.calculateEqualSplits(amount: total, userIds: ids))
            }
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
            if let receipt = parsedReceipt {
                return .success(service.calculateItemSplits(receipt: receipt, participantIds: ids))
            }
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
                if let receipt = parsedReceipt {
                    expenseItems = receipt.items.compactMap { item in
                        guard let owner = item.assignedTo else { return nil }
                        return NewExpenseItem(name: item.name, price: item.price, taxPortion: item.taxPortion, assignedTo: owner)
                    }
                }
                let gid: UUID? = context == .friends ? nil : selectedGroupId
                let lineItemReceipt = parsedReceipt.map { !$0.items.isEmpty } ?? false
                let expense = try await service.createExpense(
                    groupId: gid,
                    paidBy: paidBy,
                    title: title,
                    amount: totalWithTax,
                    currency: currency,
                    category: category.rawValue,
                    splitType: lineItemReceipt ? .byItem : splitType,
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
