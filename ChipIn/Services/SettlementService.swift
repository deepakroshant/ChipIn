import Foundation
import UIKit

struct SettlementService {
    func settle(fromUserId: UUID, toUserId: UUID, amount: Decimal, groupId: UUID?, method: String) async throws {
        try await supabase.from("settlements").insert([
            "from_user_id": fromUserId.uuidString,
            "to_user_id": toUserId.uuidString,
            "amount": "\(amount)",
            "group_id": groupId?.uuidString as Any,
            "method": method
        ]).execute()

        try await supabase
            .from("expense_splits")
            .update(["is_settled": true])
            .eq("user_id", value: fromUserId)
            .execute()
    }

    @MainActor
    func openBankApp(_ bank: BankApp) {
        guard let url = bank.url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
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
}
