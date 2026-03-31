import Foundation

struct Expense: Codable, Identifiable, Hashable {
    let id: UUID
    /// `nil` = personal / friends split (no group).
    let groupId: UUID?
    let paidBy: UUID
    var title: String
    var totalAmount: Decimal
    var currency: String
    var cadAmount: Decimal
    var category: String
    var receiptURL: String?
    var isRecurring: Bool
    var recurrenceInterval: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, currency, category
        case groupId = "group_id"
        case paidBy = "paid_by"
        case title
        case totalAmount = "total_amount"
        case cadAmount = "cad_amount"
        case receiptURL = "receipt_url"
        case isRecurring = "is_recurring"
        case recurrenceInterval = "recurrence_interval"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ExpenseItem: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    var name: String
    var price: Decimal
    var taxPortion: Decimal
    var assignedTo: UUID

    enum CodingKeys: String, CodingKey {
        case id, name, price
        case expenseId = "expense_id"
        case taxPortion = "tax_portion"
        case assignedTo = "assigned_to"
    }
}

struct ExpenseSplit: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    var owedAmount: Decimal
    var splitType: String
    var isSettled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case userId = "user_id"
        case owedAmount = "owed_amount"
        case splitType = "split_type"
        case isSettled = "is_settled"
    }
}

enum SplitType: String, CaseIterable {
    case equal, percent, exact, byItem, shares
}

enum ExpenseCategory: String, CaseIterable {
    case food = "Food"
    case travel = "Travel"
    case rent = "Rent"
    case fun = "Fun"
    case utilities = "Utilities"
    case other = "Other"

    var emoji: String {
        switch self {
        case .food: return "🍔"
        case .travel: return "✈️"
        case .rent: return "🏠"
        case .fun: return "🎉"
        case .utilities: return "💡"
        case .other: return "📦"
        }
    }
}
