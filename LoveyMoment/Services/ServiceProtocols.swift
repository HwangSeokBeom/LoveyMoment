import Foundation
import UserNotifications

protocol SleepSignalProviding {
    func currentSleepSignalResult(for snapshot: ConversationSnapshot) async -> SleepSignalFetchResult
}

extension SleepSignalProviding {
    func currentSleepSignal(for snapshot: ConversationSnapshot) async -> SleepSignal {
        await currentSleepSignalResult(for: snapshot).signal
    }
}

protocol MomentAnalyzing {
    func analyze(snapshot: ConversationSnapshot, sleepSignal: SleepSignal) -> MomentAnalysis
}

protocol MomentNotificationScheduling {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func schedule(moments: [MomentMessage], settings: MomentSettings, characterID: UUID) async -> [MomentMessage]
    func scheduleTest(moment: MomentMessage, characterID: UUID) async -> String?
    func cancel(momentIDs: [MomentMessage.ID]) async
    func handlePreviewTap(moment: MomentMessage)
}

/// 캐릭터 메시지 알림(듀오링고식 리마인더) 예약/취소.
/// 현재는 로컬 알림 구현이지만, route/userInfo 구조는 추후 APNs로 교체 가능하도록 유지한다.
protocol CharacterNotificationScheduling {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// plan 한 건을 예약한다. 실패 시 nil.
    func schedule(plan: CharacterNotificationPlan) async -> String?
    /// 10초/지정 초 뒤 테스트 알림. 동일 plan body/userInfo를 사용한다.
    func scheduleTest(plan: CharacterNotificationPlan, after seconds: TimeInterval) async -> String?
    /// 특정 캐릭터/타입의 pending 알림을 prefix로 모두 취소.
    func cancel(characterId: UUID, type: CharacterNotificationType) async
    /// 특정 캐릭터의 모든 캐릭터 알림 취소.
    func cancelAll(characterId: UUID) async
    /// 현재 pending 중인 캐릭터 알림 식별자 목록.
    func pendingIdentifiers() async -> [String]
}

protocol ConversationGenerating {
    var generationMode: ConversationGenerationMode { get }
    var compileAvailability: Bool { get }

    func availabilityStatus() -> ConversationGenerationAvailability
    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics
    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage
    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage
    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage
}

enum ConversationScenario: String, CaseIterable, Identifiable, Hashable {
    case bedtime
    case dawn
    case morning
    case delayedReply
    case relationshipProgress
    case sulking
    case worried

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bedtime: return "자기 전"
        case .dawn: return "새벽"
        case .morning: return "아침"
        case .delayedReply: return "답장 지연"
        case .relationshipProgress: return "관계 진전"
        case .sulking: return "서운함"
        case .worried: return "걱정"
        }
    }

    var logTag: String {
        switch self {
        case .bedtime: return "bedtime"
        case .dawn: return "dawn"
        case .morning: return "morning"
        case .delayedReply: return "delayedReply"
        case .relationshipProgress: return "relationshipShift"
        case .sulking: return "jealousy"
        case .worried: return "worry"
        }
    }

    var iconName: String {
        switch self {
        case .bedtime: return "moon.stars.fill"
        case .dawn: return "sparkle"
        case .morning: return "sun.max.fill"
        case .delayedReply: return "clock.badge.exclamationmark.fill"
        case .relationshipProgress: return "heart.circle.fill"
        case .sulking: return "cloud.rain.fill"
        case .worried: return "cross.case.fill"
        }
    }
}
