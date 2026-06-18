import UserNotifications

/// 캐릭터 메시지 알림을 로컬 알림으로 예약한다.
/// userInfo는 기존 AppNotificationRoute 리더가 읽는 키(characterId/momentId/momentType/deepLinkTarget/title/body)를
/// 그대로 채워 기존 딥링크→ChatView 삽입 파이프라인을 재사용하고, 진단용 키(notificationType/source)를 추가한다.
final class LocalCharacterNotificationScheduler: CharacterNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("[CharacterNotification] permission request=result granted=\(granted)")
            return granted
        } catch {
            print("[CharacterNotification] permission request=failed error=\(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func schedule(plan: CharacterNotificationPlan) async -> String? {
        guard await ensureAuthorization() else {
            print("[CharacterNotification] schedule skipped permission=false type=\(plan.type.rawValue)")
            return nil
        }

        let interval = max(plan.scheduledDate.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return await add(plan: plan, trigger: trigger, generatedMode: "scheduled")
    }

    func scheduleTest(plan: CharacterNotificationPlan, after seconds: TimeInterval) async -> String? {
        guard await ensureAuthorization() else {
            print("[CharacterNotification] scheduleTest skipped permission=false")
            return nil
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        return await add(plan: plan, trigger: trigger, generatedMode: "test")
    }

    func cancel(characterId: UUID, type: CharacterNotificationType) async {
        let prefix = CharacterNotificationPlan.identifierPrefix(characterId: characterId, type: type)
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        print("[CharacterNotification] cancel type=\(type.rawValue) ids=\(ids.count)")
    }

    func cancelAll(characterId: UUID) async {
        let prefix = "char.\(characterId.uuidString)."
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        print("[CharacterNotification] cancelAll characterId=\(characterId) ids=\(ids.count)")
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("char.") }
    }

    private func ensureAuthorization() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            print("[CharacterNotification] permission=denied showInAppGuide")
            return false
        @unknown default:
            return false
        }
    }

    private func add(
        plan: CharacterNotificationPlan,
        trigger: UNNotificationTrigger,
        generatedMode: String
    ) async -> String? {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.userInfo = [
            "characterId": plan.characterId.uuidString,
            "momentId": plan.momentId.uuidString,
            "momentType": plan.type.compatibleMomentType.rawValue,
            "deepLinkTarget": plan.deepLinkTarget,
            "title": plan.title,
            "body": plan.body,
            "notificationType": plan.type.rawValue,
            "source": plan.source.rawValue,
            "generatedMode": generatedMode
        ]

        let request = UNNotificationRequest(
            identifier: plan.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[CharacterNotification] schedule type=\(plan.type.rawValue) characterId=\(plan.characterId) fireIn=\(Int(plan.scheduledDate.timeIntervalSinceNow))s id=\(plan.notificationIdentifier)")
            return plan.notificationIdentifier
        } catch {
            print("[CharacterNotification] schedule failed id=\(plan.notificationIdentifier) error=\(error.localizedDescription)")
            return nil
        }
    }
}
