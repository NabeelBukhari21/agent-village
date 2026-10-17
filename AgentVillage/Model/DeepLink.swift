import Foundation
import Observation

/// Links like `agentvillage://open?task=<id>&agent=<id>` — sent by phone push
/// (ntfy) so tapping an alert opens the right agent or report.
@MainActor
@Observable
final class DeepLink {
    static let shared = DeepLink()

    struct Target: Equatable {
        let taskID: String?
        let agentID: String?
        let id = UUID()
    }

    /// Waiting to be handled (the app may still be loading or connecting).
    var pending: Target?

    func receive(_ url: URL) {
        guard url.scheme == "agentvillage" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        pending = Target(taskID: value("task"), agentID: value("agent"))
    }
}
