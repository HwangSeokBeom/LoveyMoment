import Foundation

struct CharacterProfile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let ageLabel: String
    let subtitle: String
    let shortDescription: String
    let personalitySummary: String
    let defaultToneKeywords: [String]
    let tags: [String]
    let profileImageName: String?
    let generatedAvatarKey: String
    let worldSettingID: UUID
    let initialRelationshipStageID: UUID
    let openingScene: String
    let sleepMomentSettings: MomentSettings
    let creatorNote: String
    let stats: CharacterStats
}

struct CharacterStats: Hashable {
    let likesText: String
    let characterType: String
    let creatorName: String
    let storyCount: Int
    let communityPosts: Int
    let updateNote: String
}

struct WorldSetting: Identifiable, Hashable {
    let id: UUID
    let title: String
    let categoryTags: [String]
    let summary: String
    let relationshipRules: String
    let sceneKeywords: [String]
}

struct RelationshipStage: Identifiable, Hashable {
    let id: UUID
    let label: String
    let progressHint: String
    let description: String
    let allowedToneRange: String
}

struct ChatMessage: Identifiable, Hashable {
    enum Sender: String, Hashable {
        case user
        case character
        case system
    }

    let id: UUID
    let sender: Sender
    let text: String
    let createdAt: Date
    let isMomentInserted: Bool
    let sourceMomentID: UUID?
    let generationMode: ConversationGenerationMode?

    init(
        id: UUID = UUID(),
        sender: Sender,
        text: String,
        createdAt: Date = Date(),
        isMomentInserted: Bool = false,
        sourceMomentID: UUID? = nil,
        generationMode: ConversationGenerationMode? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.createdAt = createdAt
        self.isMomentInserted = isMomentInserted
        self.sourceMomentID = sourceMomentID
        self.generationMode = generationMode
    }
}

struct ConversationSnapshot: Identifiable, Hashable {
    let id: UUID
    let character: CharacterProfile
    let worldSetting: WorldSetting
    let relationshipStage: RelationshipStage
    let recentMessages: [ChatMessage]
    let lastSceneSummary: String
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        character: CharacterProfile,
        worldSetting: WorldSetting,
        relationshipStage: RelationshipStage,
        recentMessages: [ChatMessage],
        lastSceneSummary: String,
        capturedAt: Date
    ) {
        self.id = id
        self.character = character
        self.worldSetting = worldSetting
        self.relationshipStage = relationshipStage
        self.recentMessages = recentMessages
        self.lastSceneSummary = lastSceneSummary
        self.capturedAt = capturedAt
    }
}

struct SleepSignal: Hashable {
    enum Source: String, Hashable {
        case mock
        case healthKit
        case sleepFocus
        case manualFallback
    }

    enum Confidence: String, Hashable {
        case low
        case medium
        case high
    }

    let estimatedBedtime: String
    let estimatedWakeTime: String
    let source: Source
    let confidence: Confidence
    let explanation: String
}

enum SleepSignalSource: String, Hashable {
    case healthKitRealData
    case mockFallback
    case unavailable

    var displayName: String {
        switch self {
        case .healthKitRealData: return "HealthKit 실데이터"
        case .mockFallback: return "Mock fallback"
        case .unavailable: return "Unavailable"
        }
    }
}

struct SleepSignalDiagnostics: Hashable {
    var authorizationStatus: String
    var source: SleepSignalSource
    var sampleCount: Int
    var lastSampleDate: Date?
    var fallbackReason: String?
    var isSimulator: Bool
    var totalSleepMinutes: Int
    var estimatedBedtime: String?
    var estimatedWakeTime: String?
    var dataSources: [String]
    var lastUpdatedAt: Date

    static var empty: SleepSignalDiagnostics {
        SleepSignalDiagnostics(
            authorizationStatus: "notChecked",
            source: .unavailable,
            sampleCount: 0,
            lastSampleDate: nil,
            fallbackReason: nil,
            isSimulator: Self.isRunningOnSimulator,
            totalSleepMinutes: 0,
            estimatedBedtime: nil,
            estimatedWakeTime: nil,
            dataSources: [],
            lastUpdatedAt: Date()
        )
    }

    static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

struct SleepSignalFetchResult: Hashable {
    let signal: SleepSignal
    let diagnostics: SleepSignalDiagnostics
}

struct MomentToneDecision: Identifiable, Hashable {
    let id: UUID
    let toneLabel: String
    let intensity: String
    let reason: String
    let styleKeywords: [String]
    let avoidRules: [String]

    init(
        id: UUID = UUID(),
        toneLabel: String,
        intensity: String,
        reason: String,
        styleKeywords: [String],
        avoidRules: [String]
    ) {
        self.id = id
        self.toneLabel = toneLabel
        self.intensity = intensity
        self.reason = reason
        self.styleKeywords = styleKeywords
        self.avoidRules = avoidRules
    }
}

struct MomentMessage: Identifiable, Hashable {
    enum MomentType: String, Hashable {
        case bedtime
        case morning

        var displayName: String {
            switch self {
            case .bedtime: return "자기 전 Moment"
            case .morning: return "아침 Moment"
            }
        }
    }

    let id: UUID
    let type: MomentType
    let characterName: String
    let title: String
    let body: String
    let scheduledAt: String
    let isEnabled: Bool
    let analysisID: UUID
    let generationMode: ConversationGenerationMode?

    init(
        id: UUID = UUID(),
        type: MomentType,
        characterName: String,
        title: String,
        body: String,
        scheduledAt: String,
        isEnabled: Bool,
        analysisID: UUID,
        generationMode: ConversationGenerationMode? = nil
    ) {
        self.id = id
        self.type = type
        self.characterName = characterName
        self.title = title
        self.body = body
        self.scheduledAt = scheduledAt
        self.isEnabled = isEnabled
        self.analysisID = analysisID
        self.generationMode = generationMode
    }

    func withEnabled(_ value: Bool) -> MomentMessage {
        MomentMessage(
            id: id,
            type: type,
            characterName: characterName,
            title: title,
            body: body,
            scheduledAt: scheduledAt,
            isEnabled: value,
            analysisID: analysisID,
            generationMode: generationMode
        )
    }
}

struct MomentSettings: Hashable {
    enum NotificationMode: String, Hashable {
        case inAppPreviewOnly
        case localNotification
    }

    var isBedtimeMomentEnabled = true
    var isMorningMomentEnabled = true
    var notificationMode: NotificationMode = .localNotification
}

struct MomentAnalysis: Identifiable, Hashable {
    let id: UUID
    let snapshotID: UUID
    let sleepSignal: SleepSignal
    let worldInsight: String
    let characterInsight: String
    let relationshipInsight: String
    let lastSceneInsight: String
    let emotionInsight: String
    let toneDecision: MomentToneDecision
    let bedtimeMoment: MomentMessage
    let morningMoment: MomentMessage
    let createdAt: Date
}
