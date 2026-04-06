import Foundation

/// Shared "hide balances" formatting for Home and related screens.
enum BalancePrivacy {
    static let masked = "••••"

    static func currency(_ amount: Decimal, code: String, hidden: Bool) -> String {
        if hidden { return masked }
        return amount.formatted(.currency(code: code))
    }
}
