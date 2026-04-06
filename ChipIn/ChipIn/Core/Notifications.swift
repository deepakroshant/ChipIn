import Foundation

extension Notification.Name {
    static let dataDidUpdate = Notification.Name("dataDidUpdate")
    /// userInfo["message"] = String — ContentView shows a toast (e.g. “Expense saved”).
    static let chipInToast = Notification.Name("chipInToast")
}
