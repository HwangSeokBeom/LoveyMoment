import Foundation

struct AppNotificationRoute: Identifiable, Hashable {
    let characterId: UUID
    let momentId: UUID
    let momentType: MomentMessage.MomentType
    let deepLinkTarget: String
    let title: String
    let body: String

    var id: String {
        "\(characterId.uuidString)-\(momentId.uuidString)-\(momentType.rawValue)-\(deepLinkTarget)"
    }

    init(
        characterId: UUID,
        momentId: UUID,
        momentType: MomentMessage.MomentType,
        deepLinkTarget: String,
        title: String,
        body: String
    ) {
        self.characterId = characterId
        self.momentId = momentId
        self.momentType = momentType
        self.deepLinkTarget = deepLinkTarget
        self.title = title
        self.body = body
    }

    init?(
        userInfo: [AnyHashable: Any],
        fallbackTitle: String = "Lovey Moment",
        fallbackBody: String = "알림에서 이어진 Moment예요."
    ) {
        guard
            let characterIdText = userInfo["characterId"] as? String,
            let characterId = UUID(uuidString: characterIdText)
        else {
            print("[DeepLink] invalidPayload missing=characterId")
            return nil
        }

        let momentIdText = userInfo["momentId"] as? String
        let momentId = momentIdText.flatMap(UUID.init(uuidString:)) ?? UUID()
        let typeText = userInfo["momentType"] as? String
        let momentType = typeText.flatMap(MomentMessage.MomentType.init(rawValue:)) ?? .bedtime
        let target = userInfo["deepLinkTarget"] as? String ?? "chat"
        let title = userInfo["title"] as? String ?? fallbackTitle
        let body = userInfo["body"] as? String ?? fallbackBody

        self.characterId = characterId
        self.momentId = momentId
        self.momentType = momentType
        self.deepLinkTarget = target
        self.title = title
        self.body = body
    }
}
