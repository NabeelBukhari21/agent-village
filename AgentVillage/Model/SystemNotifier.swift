import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#endif

/// Posts real system notifications (lock screen / Notification Center) when the app
/// isn't in front, with Approve and Deny buttons for approval requests.
@MainActor
final class SystemNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SystemNotifier()

    private weak var model: WorldModel?
    /// True while the app is on screen; in-app banners are used instead then.
    var appActive = true
    private var asked = false

    private static let approvalCategory = "AGENT_APPROVAL"
    private static let approve = "APPROVE"
    private static let deny = "DENY"

    func attach(_ model: WorldModel) {
        self.model = model
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let approve = UNNotificationAction(identifier: Self.approve, title: "Approve", options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: Self.deny, title: "Deny", options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.approvalCategory, actions: [approve, deny], intentIdentifiers: []),
        ])
        model.onNotice = { [weak self] n in self?.post(n) }
    }

    /// Ask for permission once, the first time real agents connect.
    func requestPermissionIfNeeded() {
        guard !asked else { return }
        asked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func post(_ n: AppNotice) {
        Haptics.play(n.kind)
        guard !appActive, n.kind == .approval || n.kind == .done || n.kind == .failed else { return }
        let content = UNMutableNotificationContent()
        content.title = n.title.capitalized
        content.body = n.body
        content.sound = .default
        content.threadIdentifier = n.agentID ?? "village"
        content.userInfo = ["agent": n.agentID ?? "", "server": n.serverID ?? "", "result": n.resultID ?? ""]
        if n.kind == .approval {
            content.categoryIdentifier = Self.approvalCategory
            content.interruptionLevel = .timeSensitive
        }
        let req = UNNotificationRequest(identifier: n.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The app is open: the in-app banner already shows it.
        completionHandler([])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let agentID = info["agent"] as? String ?? ""
        let action = response.actionIdentifier
        Task { @MainActor in
            guard let model = self.model, let a = model.agent(agentID) else { completionHandler(); return }
            switch action {
            case Self.approve: model.approve(a)
            case Self.deny: model.deny(a)
            default: model.selectedID = agentID
            }
            completionHandler()
        }
    }
}

/// Small taptic feedback for notifications (iPhone only).
enum Haptics {
    @MainActor static func play(_ kind: AppNotice.Kind) {
        #if os(iOS)
        let g = UINotificationFeedbackGenerator()
        switch kind {
        case .approval: g.notificationOccurred(.warning)
        case .done: g.notificationOccurred(.success)
        case .failed: g.notificationOccurred(.error)
        default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}
