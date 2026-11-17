import AppKit
import MarginCore
import UserNotifications

/// Quiet banners (never a sound) when an AI tool changes a note while Anthology is in the background.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    static let enabledKey = "notifyOnAIChanges"
    weak var library: LibraryModel?

    var isEnabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }

    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func post(_ item: ActivityItem) {
        guard isEnabled, !NSApp.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(item.topicTitle) › \(item.noteTitle)"
        content.subtitle = item.entry.by.displayName
        content.body = item.entry.summary
        content.sound = nil
        content.threadIdentifier = item.topicID
        content.userInfo = ["noteID": item.noteID]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: item.id, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.content.userInfo["noteID"] as? String
        await MainActor.run {
            if let id { library?.open(noteID: id) }
            NSApp.activate()
            for window in NSApp.windows where window.identifier?.rawValue.contains("library") == true { window.makeKeyAndOrderFront(nil) }
        }
    }
}

