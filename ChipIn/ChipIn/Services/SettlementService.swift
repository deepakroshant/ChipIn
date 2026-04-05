import Foundation
import UIKit
import Supabase
import PostgREST

struct SettlementService {
    func settle(fromUserId: UUID, toUserId: UUID, amount: Decimal, groupId: UUID?, method: String) async throws {
        struct SettlementInsert: Encodable {
            let from_user_id: String
            let to_user_id: String
            let amount: String
            let group_id: String?
            let method: String
        }
        let payload = SettlementInsert(
            from_user_id: fromUserId.uuidString,
            to_user_id: toUserId.uuidString,
            amount: "\(amount)",
            group_id: groupId?.uuidString,
            method: method
        )
        try await supabase.from("settlements").insert(payload).execute()

        try await supabase
            .from("expense_splits")
            .update(["is_settled": true])
            .eq("user_id", value: fromUserId)
            .execute()
    }

    @MainActor
    func openBankApp(_ bank: BankApp) {
        if let url = bank.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = bank.webFallbackURL {
            UIApplication.shared.open(fallback)
        }
    }

    /// Opens Mail app pre-filled with an Interac e-Transfer request/send template.
    @MainActor
    func openInteracEmail(
        to email: String,
        amount: Decimal,
        recipientName: String,
        senderName: String,
        isRequest: Bool
    ) {
        let amountStr = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
        let subject = isRequest
            ? "Interac e-Transfer Request — $\(amountStr) CAD"
            : "Interac e-Transfer — $\(amountStr) CAD"
        let body = isRequest
            ? "Hi \(recipientName),\n\nPlease send $\(amountStr) CAD via Interac e-Transfer to settle our ChipIn balance.\n\nThanks,\n\(senderName)"
            : "Hi \(recipientName),\n\nI've sent you $\(amountStr) CAD via Interac e-Transfer for our ChipIn balance.\n\nThanks,\n\(senderName)"

        var components = URLComponents(string: "mailto:\(email)")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

enum BankApp: String, CaseIterable, Identifiable {
    case td = "TD Bank"
    case rbc = "RBC"
    case scotiabank = "Scotiabank"
    case bmo = "BMO"
    case cibc = "CIBC"
    case tangerine = "Tangerine"
    case eq = "EQ Bank"
    case wealthsimple = "Wealthsimple"

    var id: String { rawValue }

    var url: URL? {
        switch self {
        case .td: return URL(string: "tdct://")
        case .rbc: return URL(string: "rbcmobile://")
        case .scotiabank: return URL(string: "scotiabank://")
        case .bmo: return URL(string: "bmo://")
        case .cibc: return URL(string: "cibc://")
        case .tangerine: return URL(string: "tangerine://")
        case .eq: return URL(string: "eqbank://")
        case .wealthsimple: return URL(string: "wealthsimple://")
        }
    }

    var webFallbackURL: URL? {
        switch self {
        case .td: return URL(string: "https://www.td.com/ca/en/personal-banking")
        case .rbc: return URL(string: "https://www.rbcroyalbank.com/ways-to-bank/online-banking/")
        case .scotiabank: return URL(string: "https://www.scotiabank.com/ca/en/personal.html")
        case .bmo: return URL(string: "https://www.bmo.com/en-ca/main/personal/online-banking/")
        case .cibc: return URL(string: "https://www.cibc.com/en/personal-banking/ways-to-bank/online-banking.html")
        case .tangerine: return URL(string: "https://www.tangerine.ca/en/")
        case .eq: return URL(string: "https://www.eqbank.ca/")
        case .wealthsimple: return URL(string: "https://www.wealthsimple.com/en-ca")
        }
    }

    var emoji: String {
        switch self {
        case .td: return "🏦"
        case .rbc: return "🦁"
        case .scotiabank: return "🌟"
        case .bmo: return "🔵"
        case .cibc: return "🔴"
        case .tangerine: return "🍊"
        case .eq: return "💚"
        case .wealthsimple: return "📈"
        }
    }
}
