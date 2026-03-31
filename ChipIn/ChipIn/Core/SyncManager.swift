import SwiftUI
import Supabase
import Realtime

@MainActor
@Observable
class SyncManager {
    var isConnected = false
    private var channel: RealtimeChannelV2?

    func startListening(onUpdate: @escaping () async -> Void) async {
        let ch = supabase.channel("app-updates")

        let tables = ["expenses", "expense_splits", "settlements", "comments"]
        for table in tables {
            ch.onPostgresChange(AnyAction.self, schema: "public", table: table) { _ in
                Task { await onUpdate() }
            }
        }

        try? await ch.subscribeWithError()
        channel = ch
        isConnected = true
    }

    func stopListening() async {
        if let ch = channel {
            await supabase.removeChannel(ch)
            channel = nil
            isConnected = false
        }
    }
}
