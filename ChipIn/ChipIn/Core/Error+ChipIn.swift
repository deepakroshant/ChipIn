import Foundation

extension Error {
    /// SwiftUI `.task` / tab switches cancel in-flight async work — not a user-visible failure.
    func chipInShouldShowInUI() -> Bool {
        if self is CancellationError { return false }
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return false }
        return true
    }
}
