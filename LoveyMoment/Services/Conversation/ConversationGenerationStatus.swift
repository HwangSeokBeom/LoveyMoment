import Foundation

enum ConversationGenerationMode: String, Hashable {
    case highQualityAssistant
    case nativeFoundationModel
    case localDeterministicFallback
    case unavailable

    var displayName: String {
        switch self {
        case .highQualityAssistant: return "High Quality Assistant"
        case .nativeFoundationModel: return "Native LLM / On-device"
        case .localDeterministicFallback: return "Local Generator fallback"
        case .unavailable: return "Unavailable"
        }
    }

    var badgeText: String {
        switch self {
        case .highQualityAssistant: return "High Quality"
        case .nativeFoundationModel: return "On-device · Native LLM"
        case .localDeterministicFallback: return "Local fallback"
        case .unavailable: return "Unavailable"
        }
    }
}

enum ConversationEngineMode: String, CaseIterable, Identifiable, Hashable {
    case auto
    case nativeFirst
    case deterministicOnly
    case diagnosticsOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .nativeFirst: return "Native first"
        case .deterministicOnly: return "Deterministic only"
        case .diagnosticsOnly: return "Diagnostics only"
        }
    }

    var nativeChatEnabled: Bool {
        switch self {
        case .auto, .nativeFirst: return true
        case .deterministicOnly, .diagnosticsOnly: return false
        }
    }
}

enum ConversationEngineSettings {
    private static let defaultsKey = "LoveyMoment.ConversationEngineMode"

    static var currentMode: ConversationEngineMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let mode = ConversationEngineMode(rawValue: raw) {
                return mode
            }
            return .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}

enum ConversationGenerationAvailability: Hashable {
    case available
    case unavailable(reason: String)

    var displayText: String {
        switch self {
        case .available:
            return "available"
        case .unavailable(let reason):
            return "unavailable: \(reason)"
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var reasonText: String {
        switch self {
        case .available: return "available"
        case .unavailable(let reason): return reason
        }
    }
}

struct ConversationGenerationContext: Hashable {
    let character: CharacterProfile
    let world: WorldSetting
    let relationshipStage: RelationshipStage
    let messages: [ChatMessage]
    var memory: ConversationMemory = .empty
    let sleepSignal: SleepSignal?
    let lastSceneSummary: String
    let now: Date
}

struct ConversationMemory: Hashable {
    var userName: String?
    var previousUserNames: [String]
    var lastUserSelfIntroduction: String?
    var lastNameUpdatedAt: Date?
    var lastNameUpdateReason: String?
    var knownFacts: [String]
    var recentSceneSummary: String?
    var relationshipHints: [String]
    var updatedAt: Date?

    init(
        userName: String? = nil,
        previousUserNames: [String] = [],
        lastUserSelfIntroduction: String? = nil,
        lastNameUpdatedAt: Date? = nil,
        lastNameUpdateReason: String? = nil,
        knownFacts: [String] = [],
        recentSceneSummary: String? = nil,
        relationshipHints: [String] = [],
        updatedAt: Date? = nil
    ) {
        self.userName = userName
        self.previousUserNames = previousUserNames
        self.lastUserSelfIntroduction = lastUserSelfIntroduction
        self.lastNameUpdatedAt = lastNameUpdatedAt
        self.lastNameUpdateReason = lastNameUpdateReason
        self.knownFacts = knownFacts
        self.recentSceneSummary = recentSceneSummary
        self.relationshipHints = relationshipHints
        self.updatedAt = updatedAt
    }

    static let empty = ConversationMemory(
        userName: nil,
        previousUserNames: [],
        lastUserSelfIntroduction: nil,
        lastNameUpdatedAt: nil,
        lastNameUpdateReason: nil,
        knownFacts: [],
        recentSceneSummary: nil,
        relationshipHints: [],
        updatedAt: nil
    )
}

struct MomentGenerationContext: Hashable {
    let type: MomentMessage.MomentType
    let baseMoment: MomentMessage
    let snapshot: ConversationSnapshot
    let sleepSignal: SleepSignal
    let momentSettings: MomentSettings
    let analysisSummary: String
}

struct NativeLLMDiagnostics: Hashable {
    var canImportFoundationModels: Bool
    var osAvailable: Bool
    var runtimeAvailable: Bool
    var contextCharacterCount: Int
    var lastGenerationStartedAt: Date?
    var lastGenerationCompletedAt: Date?
    var lastGenerationSucceeded: Bool
    var lastFailureReason: String?
    var lastFallbackReason: String?
    var lastGeneratedCharacterCount: Int
    var lastGeneratedTextPreview: String?
    var lastGenerationMode: ConversationGenerationMode
    var noExternalAPI: Bool

    static var empty: NativeLLMDiagnostics {
        NativeLLMDiagnostics(
            canImportFoundationModels: false,
            osAvailable: false,
            runtimeAvailable: false,
            contextCharacterCount: 0,
            lastGenerationStartedAt: nil,
            lastGenerationCompletedAt: nil,
            lastGenerationSucceeded: false,
            lastFailureReason: nil,
            lastFallbackReason: nil,
            lastGeneratedCharacterCount: 0,
            lastGeneratedTextPreview: nil,
            lastGenerationMode: .unavailable,
            noExternalAPI: true
        )
    }
}
