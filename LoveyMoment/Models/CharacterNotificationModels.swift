import Foundation

/// 캐릭터가 보내는 알림의 종류. (듀오링고식 리마인더 + 캐릭터 메시지)
/// 향후 APNs remote push로 교체해도 동일한 type/route 구조를 유지한다.
enum CharacterNotificationType: String, Hashable, CaseIterable, Identifiable {
    case bedtimeMoment
    case morningMoment
    case delayedReply
    case relationshipTrigger
    case sceneContinuation
    case reengagement

    var id: String { rawValue }

    /// 사용자 화면에 노출되는 한국어 라벨. (개발자 용어 금지)
    var userFacingLabel: String {
        switch self {
        case .bedtimeMoment: return "자기 전 Moment"
        case .morningMoment: return "아침 Moment"
        case .delayedReply: return "답장 기다림"
        case .relationshipTrigger: return "관계 변화"
        case .sceneContinuation: return "이어지는 장면"
        case .reengagement: return "다시 만나요"
        }
    }

    var iconName: String {
        switch self {
        case .bedtimeMoment: return "moon.stars.fill"
        case .morningMoment: return "sun.max.fill"
        case .delayedReply: return "clock.badge.exclamationmark.fill"
        case .relationshipTrigger: return "heart.circle.fill"
        case .sceneContinuation: return "text.bubble.fill"
        case .reengagement: return "hand.wave.fill"
        }
    }

    /// 기존 Moment 딥링크 reader와 호환되는 momentType 매핑.
    var compatibleMomentType: MomentMessage.MomentType {
        switch self {
        case .morningMoment: return .morning
        default: return .bedtime
        }
    }
}

/// 알림 예약의 근거. UI에서는 userFacingLabel만 노출하고, 원시 값은 진단에서만 쓴다.
enum CharacterNotificationSource: String, Hashable {
    case healthKit
    case fallbackRhythm
    case conversationTrigger
    case manualTest

    var userFacingLabel: String {
        switch self {
        case .healthKit: return "건강 앱 수면 리듬 기반"
        case .fallbackRhythm: return "기본 리듬 사용 중"
        case .conversationTrigger: return "대화 흐름 기반"
        case .manualTest: return "테스트"
        }
    }
}

/// 예약된 캐릭터 알림 한 건. notification content + ChatView 삽입 메시지의 공통 소스.
struct CharacterNotificationPlan: Identifiable, Hashable {
    let id: UUID
    let characterId: UUID
    let characterName: String
    let type: CharacterNotificationType
    let scheduledDate: Date
    let title: String
    let body: String
    let momentId: UUID
    let source: CharacterNotificationSource
    let deepLinkTarget: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        characterId: UUID,
        characterName: String,
        type: CharacterNotificationType,
        scheduledDate: Date,
        title: String,
        body: String,
        momentId: UUID? = nil,
        source: CharacterNotificationSource,
        deepLinkTarget: String = "chat",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.characterId = characterId
        self.characterName = characterName
        self.type = type
        self.scheduledDate = scheduledDate
        self.title = title
        self.body = body
        self.momentId = momentId ?? id
        self.source = source
        self.deepLinkTarget = deepLinkTarget
        self.createdAt = createdAt
    }

    /// pending notification 식별자. characterId/type 기준 취소가 가능하도록 prefix를 구성한다.
    var notificationIdentifier: String {
        "char.\(characterId.uuidString).\(type.rawValue).\(id.uuidString)"
    }

    static func identifierPrefix(characterId: UUID, type: CharacterNotificationType) -> String {
        "char.\(characterId.uuidString).\(type.rawValue)."
    }

    /// 사용자에게 보여줄 예약 시각 텍스트. (예: "오늘 밤 11:10", "내일 아침 7:40")
    var scheduledDisplayText: String {
        CharacterNotificationPlan.displayFormatter.string(from: scheduledDate)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.setLocalizedDateFormatFromTemplate("EEE a h:mm")
        return formatter
    }()
}

/// 알림 메시지를 만들 때 참고하는 컨텍스트.
struct CharacterNotificationTriggerContext {
    let character: CharacterProfile
    let recentMessages: [ChatMessage]
    let sleepSignal: SleepSignal?
    let momentSettings: MomentSettings
    let relationshipStage: RelationshipStage
    let lastSceneSummary: String
    let appLifecycleEvent: String?
    let triggerType: CharacterNotificationType
}

/// 수면 시각 문자열("HH:mm")로부터 다음 알림 시각(Date)을 계산한다.
enum CharacterNotificationSchedule {
    /// offsetMinutes만큼 보정한 오늘/내일의 다음 시각을 반환한다. 과거면 다음 날로 보정.
    static func nextDate(
        timeString: String,
        offsetMinutes: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let (hour, minute) = parse(timeString)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let base = calendar.date(from: components) ?? now
        let target = calendar.date(byAdding: .minute, value: offsetMinutes, to: base) ?? base
        if target.timeIntervalSince(now) <= 60 {
            return calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }

    static func parse(_ timeString: String) -> (hour: Int, minute: Int) {
        let lastToken = timeString.split(separator: " ").last.map(String.init) ?? timeString
        let values = lastToken.split(separator: ":").compactMap { Int($0) }
        guard values.count == 2 else { return (23, 40) }
        return (min(max(values[0], 0), 23), min(max(values[1], 0), 59))
    }
}
