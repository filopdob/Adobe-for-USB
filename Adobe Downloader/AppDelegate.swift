import Cocoa
import SwiftUI

struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.blendingMode = .behindWindow
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.isEmphasized = true
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.minSize = NSSize(width: 800, height: 765)
        }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.characters?.lowercased() == "q" {
                if let mainWindow = NSApp.mainWindow,
                   mainWindow.sheets.isEmpty && !mainWindow.isSheet {
                    _ = self?.applicationShouldTerminate(NSApp)
                    return nil
                }
            }
            return event
        }

        PrivilegedHelperAdapter.shared.executeCommand("id -u") { _ in }
        setupStatusItem()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let hasActiveDownloads = globalNetworkManager.downloadTasks.contains { task in
            if case .downloading = task.totalStatus { return true }
            return false
        }
        
        if hasActiveDownloads {
            Task {
                for task in globalNetworkManager.downloadTasks {
                    if case .downloading = task.totalStatus {
                        await globalNewDownloadUtils.pauseDownloadTask(
                            taskId: task.id,
                            reason: .other(String(localized: "程序即将退出"))
                        )
                        await globalNetworkManager.saveTask(task)
                    }
                }

                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = String(localized: "确认退出")
                    alert.informativeText = String(localized:"有正在进行的下载任务，确定要退出吗？\n所有下载任务的进度已保存，下次启动可以继续下载")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: String(localized:"退出"))
                    alert.addButton(withTitle: String(localized:"取消"))

                    let response = alert.runModal()
                    if response == .alertSecondButtonReturn {
                        Task {
                            for task in globalNetworkManager.downloadTasks {
                                if case .paused = task.totalStatus {
                                    await globalNewDownloadUtils.resumeDownloadTask(taskId: task.id)
                                }
                            }
                        }
                    } else {
                        NSApplication.shared.terminate(0)
                    }
                }
            }
        } else {
            NSApplication.shared.terminate(nil)
        }
        return .terminateCancel
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Adobe Downloader")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: String(localized: "打开 Adobe Downloader"),
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        ))
        menu.addItem(NSMenuItem(
            title: String(localized: "检查更新"),
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        ))
        menu.addItem(NSMenuItem(
            title: String(localized: "设置…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: String(localized: "退出"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))
        
        item.menu = menu
        statusItem = item
    }
    
    @objc private func openMainWindow() {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    @objc private func checkForUpdates() {
        NotificationCenter.default.post(name: .triggerCheckForUpdates, object: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
    static let openSettings = Notification.Name("openSettings")
    static let triggerCheckForUpdates = Notification.Name("triggerCheckForUpdates")
}
