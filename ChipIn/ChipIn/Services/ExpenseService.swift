import Supabase
import Foundation

struct NewExpenseItem {
    let name: String
    let price: Decimal
    let taxPortion: Decimal
    let assignedTo: UUID
}

struct ExpenseService {
    private let currencyService = CurrencyService()

    func createExpense(
        groupId: UUID,
        paidBy: UUID,
        title: String,
        amount: Decimal,
        currency: String,
        category: String,
        splitType: SplitType,
        splits: [(userId: UUID, amount: Decimal)],
        isRecurring: Bool,
        recurrenceInterval: String?,
        items: [NewExpenseItem] = []
    ) async throws {
        let cadAmount = try await currencyService.convert(amount: amount, from: currency)

        let expense: Expense = try await supabase
            .from("expenses")
            .insert([
                "group_id": groupId.uuidString,
                "paid_by": paidBy.uuidString,
                "title": title,
                "total_amount": "\(amount)",
                "currency": currency,
                "cad_amount": "\(cadAmount)",
                "category": category,
                "is_recurring": isRecurring,
                "recurrence_interval": recurrenceInterval as Any
            ])
            .select()
            .single()
            .execute()
            .value

        let splitRows = splits.map { split in [
            "expense_id": expense.id.uuidString,
            "user_id": split.userId.uuidString,
            "owed_amount": "\(split.amount)",
            "split_type": splitType.rawValue,
            "is_settled": false
        ] as [String: Any] }
        try await supabase.from("expense_splits").insert(splitRows).execute()

        if !items.isEmpty {
            let itemRows = items.map { item in [
                "expense_id": expense.id.uuidString,
                "name": item.name,
                "price": "\(item.price)",
                "tax_portion": "\(item.taxPortion)",
                "assigned_to": item.assignedTo.uuidString
            ] as [String: Any] }
            try await supabase.from("expense_items").insert(itemRows).execute()
        }
    }

    func calculateEqualSplits(amount: Decimal, userIds: [UUID]) -> [(userId: UUID, amount: Decimal)] {
        guard !userIds.isEmpty else { return [] }
        let share = (amount / Decimal(userIds.count)).rounded(.bankers)
        let remainder = amount - share * Decimal(userIds.count)
        return userIds.enumerated().map { idx, userId in
            (userId, idx == 0 ? share + remainder : share)
        }
    }
}
