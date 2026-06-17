import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        print("[Notification] UNUserNotificationCenterDelegate attached.")
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("[LocalNotification] willPresent id=\(notification.request.identifier)")
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let characterId = userInfo["characterId"] as? String ?? "missing"
        let momentType = userInfo["momentType"] as? String ?? "missing"
        let target = userInfo["deepLinkTarget"] as? String ?? "missing"
        print("[LocalNotification] didReceive id=\(response.notification.request.identifier) characterId=\(characterId) momentType=\(momentType) target=\(target)")
        await MainActor.run {
            NotificationCenter.default.post(name: .loveyMomentNotificationTapped, object: nil, userInfo: userInfo)
        }
    }
}

extension Notification.Name {
    static let loveyMomentNotificationTapped = Notification.Name("LoveyMomentNotificationTapped")
}
