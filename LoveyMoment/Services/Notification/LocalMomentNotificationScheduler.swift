import UserNotifications

final class LocalMomentNotificationScheduler: MomentNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        print("[NotificationPermission] status=notDetermined request=start")
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("[NotificationPermission] request=result granted=\(granted)")
            return granted
        } catch {
            print("[NotificationPermission] request=failed error=\(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        print("[NotificationPermission] currentStatus=\(settings.authorizationStatus.logName)")
        return settings.authorizationStatus
    }

    func schedule(moments: [MomentMessage], settings: MomentSettings, characterID: UUID) async -> [MomentMessage] {
        guard settings.notificationMode == .localNotification else {
            print("[LocalNotification] mode=previewOnly skipSchedule")
            return moments
        }

        let granted = await ensureAuthorization()
        guard granted else {
            print("[LocalNotification] permission=false keepPreviewOnly")
            return moments
        }

        for moment in moments {
            _ = await schedule(moment: moment, characterID: characterID, trigger: calendarTrigger(for: moment))
        }
        return moments
    }

    func scheduleTest(moment: MomentMessage, characterID: UUID) async -> String? {
        let granted = await ensureAuthorization()
        guard granted else {
            print("[LocalNotification] scheduleTest skipped permission=false characterId=\(characterID) momentType=\(moment.type.rawValue)")
            return nil
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let timestamp = Int(Date().timeIntervalSince1970)
        let identifier = await schedule(
            moment: moment,
            characterID: characterID,
            trigger: trigger,
            identifier: "\(characterID.uuidString)-\(moment.type.rawValue)-\(timestamp)"
        )
        if let identifier {
            print("[LocalNotification] scheduleTest characterId=\(characterID) momentType=\(moment.type.rawValue) seconds=10 id=\(identifier)")
        }
        return identifier
    }

    func cancel(momentIDs: [MomentMessage.ID]) async {
        let identifiers = momentIDs.map(\.uuidString)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers.map { "\($0)-test" })
        print("[LocalNotification] cancel ids=\(identifiers)")
    }

    func handlePreviewTap(moment: MomentMessage) {
        print("[DeepLink] previewTap momentId=\(moment.id)")
    }

    private func ensureAuthorization() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            print("[NotificationPermission] status=\(status.logName) skipRequest")
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            print("[NotificationPermission] status=denied showInAppGuide")
            return false
        @unknown default:
            print("[NotificationPermission] status=unknown showInAppGuide")
            return false
        }
    }

    private func schedule(
        moment: MomentMessage,
        characterID: UUID,
        trigger: UNNotificationTrigger,
        identifier: String? = nil
    ) async -> String? {
        let content = UNMutableNotificationContent()
        content.title = moment.title
        content.body = moment.body
        content.sound = .default
        content.userInfo = [
            "characterId": characterID.uuidString,
            "momentId": moment.id.uuidString,
            "momentType": moment.type.rawValue,
            "deepLinkTarget": "chat",
            "title": moment.title,
            "body": moment.body
        ]

        let requestIdentifier = identifier ?? moment.id.uuidString
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("[LocalNotification] scheduled characterId=\(characterID) momentType=\(moment.type.rawValue) id=\(requestIdentifier)")
            return requestIdentifier
        } catch {
            print("[LocalNotification] failed id=\(requestIdentifier) error=\(error.localizedDescription)")
            return nil
        }
    }

    private func calendarTrigger(for moment: MomentMessage) -> UNCalendarNotificationTrigger {
        let time = Self.extractTime(from: moment.scheduledAt)
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    private static func extractTime(from text: String) -> (hour: Int, minute: Int) {
        let parts = text.split(separator: " ")
        guard let timePart = parts.last else { return (23, 40) }
        let values = timePart.split(separator: ":").compactMap { Int($0) }
        guard values.count == 2 else { return (23, 40) }
        return (values[0], values[1])
    }
}

extension UNAuthorizationStatus {
    var logName: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}
