import UserNotifications
import UIKit
import Supabase
import Auth
import PostgREST

@MainActor
class NotificationManager {
    static let shared = NotificationManager()

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
        // Store token in users table for server-side push notifications
        if let userId = try? await supabase.auth.session.user.id {
            _ = try? await supabase
                .from("users")
                .update(["apns_token": tokenString])
                .eq("id", value: userId.uuidString)
                .execute()
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
