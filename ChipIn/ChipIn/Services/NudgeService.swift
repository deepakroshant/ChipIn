import Foundation
import Supabase

struct NudgeService {
    func sendNudge(toUserId: UUID, fromName: String, amount: Decimal) async throws {
        struct NudgePayload: Encodable {
            let nudge: Bool
            let to_user_id: String
            let message: String
        }
        _ = try? await supabase.functions.invoke(
            "send-push",
            options: .init(body: NudgePayload(
                nudge: true,
                to_user_id: toUserId.uuidString,
                message: "\(fromName) sent you a reminder — you owe $\(amount)"
            ))
        )
    }
}
