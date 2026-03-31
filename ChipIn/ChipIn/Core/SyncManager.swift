import SwiftUI
import Supabase

@MainActor
@Observable
class SyncManager {
    var isConnected = false
    private var channel: RealtimeChannelV2?

    func startListening(onUpdate: @escaping () async -> Void) async {
        let ch = await supabase.channel("app-updates")

        await ch.on(
            .postgresChanges,
            filter: PostgresJoinConfig(event: .all, schema: "public", table: "expenses")
        ) { _ in
            Task { await onUpdate() }
        }

        await ch.on(
            .postgresChanges,
            filter: PostgresJoinConfig(event: .all, schema: "public", table: "expense_splits")
        ) { _ in
            Task { await onUpdate() }
        }

        await ch.on(
            .postgresChanges,
            filter: PostgresJoinConfig(event: .all, schema: "public", table: "settlements")
        ) { _ in
            Task { await onUpdate() }
        }

        await ch.on(
            .postgresChanges,
            filter: PostgresJoinConfig(event: .all, schema: "public", table: "comments")
        ) { _ in
            Task { await onUpdate() }
        }

        await ch.subscribe()
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
