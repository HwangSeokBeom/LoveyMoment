import Foundation

enum ConversationGenerationMode: String, Hashable {
    case nativeFoundationModel
    case localDeterministicFallback
    case unavailable

    var displayName: String {
        switch self {
        case .nativeFoundationModel: return "Native LLM / On-device"
        case .localDeterministicFallback: return "Local Generator fallback"
        case .unavailable: return "Unavailable"
        }
    }

    var badgeText: String {
        switch self {
        case .nativeFoundationModel: return "On-device · Native LLM"
        case .localDeterministicFallback: return "Local fallback"
        case .unavailable: return "Unavailable"
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
}

struct ConversationGenerationContext: Hashable {
    let character: CharacterProfile
    let world: WorldSetting
    let relationshipStage: RelationshipStage
    let messages: [ChatMessage]
    let sleepSignal: SleepSignal?
    let lastSceneSummary: String
    let now: Date
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
