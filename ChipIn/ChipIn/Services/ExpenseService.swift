import Supabase
import PostgREST
import Foundation

struct NewExpenseItem {
    let name: String
    let price: Decimal
    let taxPortion: Decimal
    let assignedTo: UUID
}

struct ExpenseService {
    private let currencyService = CurrencyService()

    /// `groupId` nil = split with friends only (no group ledger).
    @discardableResult
    func createExpense(
        groupId: UUID?,
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
    ) async throws -> Expense {
        let cadAmount = try await currencyService.convert(amount: amount, from: currency)

        struct ExpenseInsert: Encodable {
            let group_id: String?
            let paid_by: String
            let title: String
            let total_amount: String
            let currency: String
            let cad_amount: String
            let category: String
            let is_recurring: Bool
            let recurrence_interval: String?
        }

        let expense: Expense = try await supabase
            .from("expenses")
            .insert(ExpenseInsert(
                group_id: groupId?.uuidString,
                paid_by: paidBy.uuidString,
                title: title,
                total_amount: "\(amount)",
                currency: currency,
                cad_amount: "\(cadAmount)",
                category: category,
                is_recurring: isRecurring,
                recurrence_interval: recurrenceInterval
            ))
            .select()
            .single()
            .execute()
            .value

        struct SplitInsert: Encodable {
            let expense_id: String
            let user_id: String
            let owed_amount: String
            let split_type: String
            let is_settled: Bool
        }
        let splitRows = splits.map { split in
            SplitInsert(
                expense_id: expense.id.uuidString,
                user_id: split.userId.uuidString,
                owed_amount: "\(split.amount)",
                split_type: splitType.rawValue,
                is_settled: false
            )
        }
        try await supabase.from("expense_splits").insert(splitRows).execute()

        if !items.isEmpty {
            struct ItemInsert: Encodable {
                let expense_id: String
                let name: String
                let price: String
                let tax_portion: String
                let assigned_to: String
            }
            let itemRows = items.map { item in
                ItemInsert(
                    expense_id: expense.id.uuidString,
                    name: item.name,
                    price: "\(item.price)",
                    tax_portion: "\(item.taxPortion)",
                    assigned_to: item.assignedTo.uuidString
                )
            }
            try await supabase.from("expense_items").insert(itemRows).execute()
        }
        return expense
    }

    func updateExpense(id: UUID, title: String, amount: Decimal, currency: String, category: String) async throws {
        struct Update: Encodable {
            let title: String
            let total_amount: String
            let currency: String
            let category: String
        }
        try await supabase
            .from("expenses")
            .update(Update(title: title, total_amount: "\(amount)", currency: currency, category: category))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteExpense(id: UUID) async throws {
        try await supabase
            .from("expenses")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Convert assigned receipt items into per-user splits.
    /// Unassigned items are spread evenly across all participants.
    func calculateItemSplits(receipt: ParsedReceipt, participantIds: [UUID]) -> [(userId: UUID, amount: Decimal)] {
        guard !participantIds.isEmpty else { return [] }
        var totals: [UUID: Decimal] = Dictionary(uniqueKeysWithValues: participantIds.map { ($0, Decimal(0)) })
        var unassignedTotal: Decimal = 0
        for item in receipt.items {
            let full = item.price + item.taxPortion
            if let owner = item.assignedTo, totals[owner] != nil {
                totals[owner]! += full
            } else {
                unassignedTotal += full
            }
        }
        if unassignedTotal > 0 {
            let share = unassignedTotal / Decimal(participantIds.count)
            for id in participantIds { totals[id]! += share }
        }
        return participantIds.map { id in (userId: id, amount: totals[id] ?? 0) }
    }

    func calculateEqualSplits(amount: Decimal, userIds: [UUID]) -> [(userId: UUID, amount: Decimal)] {
        guard !userIds.isEmpty else { return [] }
        let count = Decimal(userIds.count)
        var share = amount / count
        var rounded = Decimal()
        NSDecimalRound(&rounded, &share, 2, .bankers)
        let remainder = amount - rounded * count
        return userIds.enumerated().map { idx, userId in
            (userId, idx == 0 ? rounded + remainder : rounded)
        }
    }
}
