import UserNotifications
import UIKit
import Supabase
import Auth
import PostgREST

@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    /// If the device token arrives before Supabase restores the session, we save it and upload in `flushPendingAPNSTokenIfNeeded()`.
    private static let pendingAPNsTokenKey = "chipin.pending_apns_token"

    /// Bundled filenames for APNs `aps.sound` (must match files in `Resources/Sounds`).
    enum SoundFile {
        static let moneyOwed = "money_out.caf"
        static let moneyGained = "money_in.caf"
    }

    private init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return granted
    }

    func handleAPNSToken(_ deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        await uploadAPNsTokenToProfile(tokenString)
    }

    /// Call after sign-in or when `AuthManager` finishes loading the user so a token received before the session existed gets stored.
    func flushPendingAPNSTokenIfNeeded() async {
        guard let pending = UserDefaults.standard.string(forKey: Self.pendingAPNsTokenKey), !pending.isEmpty else { return }
        await uploadAPNsTokenToProfile(pending)
    }

    private func uploadAPNsTokenToProfile(_ tokenString: String) async {
        do {
            let userId = try await supabase.auth.session.user.id
            try await supabase
                .from("users")
                .update(["apns_token": tokenString])
                .eq("id", value: userId.uuidString)
                .execute()
            UserDefaults.standard.removeObject(forKey: Self.pendingAPNsTokenKey)
        } catch {
            UserDefaults.standard.set(tokenString, forKey: Self.pendingAPNsTokenKey)
        }
    }

    /// Schedules a local notification at 9am the day before `dueDate` for a recurring expense.
    func scheduleRecurringReminder(expenseTitle: String, dueDate: Date, expenseId: UUID) {
        let center = UNUserNotificationCenter.current()
        let identifier = "recurring-\(expenseId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "📅 \(expenseTitle) is due tomorrow"
        content.body = "Tap to add it in ChipIn and split it with your group."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelRecurringReminder(expenseId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["recurring-\(expenseId.uuidString)"])
    }

    /// Immediate local banner when the app isn’t foreground (e.g. Realtime still delivers briefly in background).
    /// `positive`: `true` = money-in tone, `false` = money-out, `nil` = system default (mixed update).
    func scheduleBalancePing(title: String, body: String, positive: Bool? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let positive {
            let file = positive ? SoundFile.moneyGained : SoundFile.moneyOwed
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: file))
        } else {
            content.sound = .default
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let request = UNNotificationRequest(identifier: "balance-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleLocalReminder(title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
