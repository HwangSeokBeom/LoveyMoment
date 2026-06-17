import UserNotifications

final class InAppMomentPreviewScheduler: MomentNotificationScheduling {
    private(set) var scheduledMoments: [MomentMessage] = []
    private(set) var lastTappedMoment: MomentMessage?

    func requestAuthorization() async -> Bool {
        print("[Notification][InApp] Authorization not required for preview scheduler.")
        return true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        .authorized
    }

    func schedule(moments: [MomentMessage], settings: MomentSettings, characterID: UUID) async -> [MomentMessage] {
        scheduledMoments = moments
        print("[Notification][InApp] Stored preview moments for \(characterID). count=\(moments.count)")
        return scheduledMoments
    }

    func scheduleTest(moment: MomentMessage, characterID: UUID) async -> String? {
        scheduledMoments = [moment]
        let identifier = "\(characterID.uuidString)-\(moment.type.rawValue)-inAppTest"
        print("[Notification][InApp] Test moment stored for \(characterID), momentID=\(moment.id), id=\(identifier)")
        return identifier
    }

    func cancel(momentIDs: [MomentMessage.ID]) async {
        scheduledMoments.removeAll { momentIDs.contains($0.id) }
    }

    func handlePreviewTap(moment: MomentMessage) {
        lastTappedMoment = moment
    }
}
