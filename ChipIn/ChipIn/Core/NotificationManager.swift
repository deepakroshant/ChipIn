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
            try? await supabase
                .from("users")
                .update(["apns_token": tokenString])
                .eq("id", value: userId.uuidString)
                .execute()
        }
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
