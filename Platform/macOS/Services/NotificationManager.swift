import Foundation
import UserNotifications
import OSLog
import SwiftProxyCore
import AppKit

/// Manages user notifications for proxy events
/// Handles notification permissions and delivery
final class NotificationManager: NSObject {
    // MARK: - Properties

    static let shared = NotificationManager()
    private let logger = OSLog(subsystem: "com.swiftproxy.app", category: "notifications")
    private var isAuthorized = false
    private var notificationCenter: UNUserNotificationCenter?
    private let isNotificationAvailable: Bool

    // MARK: - Initialization

    private override init() {
        // 检测是否在 app bundle 环境运行
        // UserNotifications 框架需要有效的 bundle 才能工作
        isNotificationAvailable = Bundle.main.bundleIdentifier != nil

        super.init()

        if isNotificationAvailable {
            notificationCenter = UNUserNotificationCenter.current()
            notificationCenter?.delegate = self
            os_log(.info, log: logger, "UserNotifications enabled")
        } else {
            os_log(.default, log: logger, "Running without app bundle - using console logging fallback")
        }
    }

    // MARK: - Public Methods

    /// Request notification permissions
    @MainActor
    func requestAuthorization() async {
        guard let center = notificationCenter else {
            os_log(.debug, log: logger, "Notifications not available - skipping authorization")
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            isAuthorized = granted

            if granted {
                os_log(.info, log: logger, "Notification authorization granted")
            } else {
                os_log(.default, log: logger, "Notification authorization denied")
            }
        } catch {
            os_log(.error, log: logger, "Failed to request notification authorization: %@", error.localizedDescription)
        }
    }

    /// Check current notification authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        guard let center = notificationCenter else {
            return .notDetermined
        }
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return settings.authorizationStatus
    }

    // MARK: - Notification Methods

    /// Show proxy enabled notification
    func notifyProxyEnabled(configuration: ProxyConfiguration) {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.debug, log: logger, "Proxy enabled: %{public}@ (%{public}@)", configuration.name, configuration.address)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Proxy Enabled"
        content.body = "Now using \(configuration.name) (\(configuration.address))"
        content.sound = .default
        content.categoryIdentifier = "PROXY_STATUS"

        sendNotification(identifier: "proxy.enabled", content: content)
    }

    /// Show proxy disabled notification
    func notifyProxyDisabled() {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.debug, log: logger, "Proxy disabled")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Proxy Disabled"
        content.body = "System proxy has been turned off"
        content.sound = .default
        content.categoryIdentifier = "PROXY_STATUS"

        sendNotification(identifier: "proxy.disabled", content: content)
    }

    /// Show proxy error notification
    func notifyProxyError(_ error: AppError) {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.error, log: logger, "Proxy error: %{public}@", error.errorDescription ?? "Unknown error")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Proxy Error"
        content.body = error.errorDescription ?? "An error occurred with the proxy"
        content.sound = .defaultCritical
        content.categoryIdentifier = "PROXY_ERROR"

        sendNotification(identifier: "proxy.error", content: content)
    }

    /// Show configuration saved notification
    func notifyConfigurationSaved(name: String) {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.debug, log: logger, "Configuration saved: %{public}@", name)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Configuration Saved"
        content.body = "'\(name)' has been saved"
        content.sound = nil // Silent notification
        content.categoryIdentifier = "CONFIG_UPDATE"

        sendNotification(identifier: "config.saved.\(UUID().uuidString)", content: content)
    }

    /// Show configuration deleted notification
    func notifyConfigurationDeleted(name: String) {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.debug, log: logger, "Configuration deleted: %{public}@", name)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Configuration Deleted"
        content.body = "'\(name)' has been removed"
        content.sound = nil
        content.categoryIdentifier = "CONFIG_UPDATE"

        sendNotification(identifier: "config.deleted.\(UUID().uuidString)", content: content)
    }

    /// Show connection test result notification
    func notifyConnectionTestResult(success: Bool, configuration: ProxyConfiguration, latency: TimeInterval? = nil) {
        guard isNotificationAvailable, isAuthorized else {
            if success {
                if let latency = latency {
                    os_log(.debug, log: logger, "Connection test successful: %{public}@ (Latency: %dms)", configuration.name, Int(latency * 1000))
                } else {
                    os_log(.debug, log: logger, "Connection test successful: %{public}@", configuration.name)
                }
            } else {
                os_log(.error, log: logger, "Connection test failed: %{public}@", configuration.name)
            }
            return
        }

        let content = UNMutableNotificationContent()

        if success {
            content.title = "Connection Test Successful"
            if let latency = latency {
                content.body = "\(configuration.name) is reachable (Latency: \(Int(latency * 1000))ms)"
            } else {
                content.body = "\(configuration.name) is reachable"
            }
            content.sound = nil
        } else {
            content.title = "Connection Test Failed"
            content.body = "Unable to reach \(configuration.name)"
            content.sound = .default
        }

        content.categoryIdentifier = "CONNECTION_TEST"

        sendNotification(identifier: "connection.test.\(UUID().uuidString)", content: content)
    }

    /// Show memory pressure notification (for debugging)
    func notifyMemoryPressure(level: String) {
        guard isNotificationAvailable, isAuthorized else {
            os_log(.default, log: logger, "Memory pressure: %{public}@", level)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Memory Pressure Warning"
        content.body = "System memory pressure: \(level)"
        content.sound = .default
        content.categoryIdentifier = "SYSTEM_ALERT"

        sendNotification(identifier: "memory.pressure.\(UUID().uuidString)", content: content)
    }

    // MARK: - Private Methods

    private func sendNotification(identifier: String, content: UNMutableNotificationContent) {
        guard let center = notificationCenter else { return }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                os_log(.error, log: self.logger, "Failed to deliver notification: %@", error.localizedDescription)
            } else {
                os_log(.debug, log: self.logger, "Notification delivered: %@", identifier)
            }
        }
    }

    /// Remove all delivered notifications
    func clearAllNotifications() {
        guard let center = notificationCenter else {
            os_log(.debug, log: logger, "Notifications not available - skipping clear")
            return
        }
        center.removeAllDeliveredNotifications()
        os_log(.debug, log: logger, "All notifications cleared")
    }

    /// Remove notifications with specific category
    func clearNotifications(category: String) {
        guard let center = notificationCenter else {
            os_log(.debug, log: logger, "Notifications not available - skipping clear for category: %@", category)
            return
        }
        center.getDeliveredNotifications { notifications in
            let identifiers = notifications
                .filter { $0.request.content.categoryIdentifier == category }
                .map { $0.request.identifier }

            center.removeDeliveredNotifications(withIdentifiers: identifiers)
            os_log(.debug, log: self.logger, "Cleared %d notifications for category: %@", identifiers.count, category)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    /// Handle notification interaction
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        os_log(.debug, log: logger, "User interacted with notification: %@", identifier)

        // Handle different notification actions
        switch response.notification.request.content.categoryIdentifier {
        case "PROXY_STATUS", "PROXY_ERROR":
            // Bring app to foreground and show main window
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }

        case "CONNECTION_TEST":
            // Could open settings or show test results
            break

        case "CONFIG_UPDATE":
            // Could open configuration list
            break

        default:
            break
        }

        completionHandler()
    }
}

