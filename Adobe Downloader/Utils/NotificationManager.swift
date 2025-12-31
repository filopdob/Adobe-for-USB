import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func notifyDownloadFinished(_ appName: String) {
        post(
            id: "download-finished-\(appName)",
            title: String(localized: "Download Finished"),
            body: String(format: String(localized: "Download finished: %1$@"), appName)
        )
    }
    
    func notifyInstallFinished(_ appName: String) {
        post(
            id: "install-finished-\(appName)",
            title: String(localized: "Install Finished"),
            body: String(format: String(localized: "Install finished: %1$@"), appName)
        )
    }
    
    func notifyUpdateAvailable(_ version: String) {
        post(
            id: "app-update-\(version)",
            title: String(localized: "Update Available"),
            body: String(format: String(localized: "A new version is available: %1$@"), version)
        )
    }
    
    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        
        center.add(request, withCompletionHandler: nil)
    }
}
