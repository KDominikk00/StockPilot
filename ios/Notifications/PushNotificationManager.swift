import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    @Published private(set) var deviceToken: String?
    @Published private(set) var registrationError: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return }
                UIApplication.shared.registerForRemoteNotifications()
            } catch {
                registrationError = error.localizedDescription
            }
        }
    }

    /// Without this, a local notification scheduled while the app is in the
    /// foreground (e.g. right after a pull-to-refresh finds something new)
    /// would be silently suppressed instead of showing a banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func handleDidRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
    }

    /// Expected on a free Apple Developer account — remote push needs the
    /// Push Notifications capability + a real provisioning profile, which
    /// requires a paid membership (see Faza 3 w planie). Local notifications
    /// below work regardless and stand in until that's set up.
    func handleDidFailToRegister(error: Error) {
        registrationError = error.localizedDescription
        deviceToken = nil
    }

    func scheduleLocalNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
