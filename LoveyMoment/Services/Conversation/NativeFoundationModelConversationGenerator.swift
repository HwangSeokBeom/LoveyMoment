import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct NativeFoundationModelConversationGenerator: ConversationGenerating {
    let generationMode: ConversationGenerationMode = .nativeFoundationModel

    var compileAvailability: Bool {
        #if canImport(FoundationModels)
        true
        #else
        false
        #endif
    }

    func availabilityStatus() -> ConversationGenerationAvailability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            Task {
                await NativeLLMDiagnosticsCenter.shared.updateAvailability(
                    canImportFoundationModels: true,
                    osAvailable: false,
                    runtimeAvailable: false,
                    failureReason: "iOS 26.0+ required"
                )
            }
            return .unavailable(reason: "iOS 26.0+ required")
        }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            Task {
                await NativeLLMDiagnosticsCenter.shared.updateAvailability(
                    canImportFoundationModels: true,
                    osAvailable: true,
                    runtimeAvailable: true,
                    failureReason: nil
                )
            }
            return .available
        case .unavailable(let reason):
            Task {
                await NativeLLMDiagnosticsCenter.shared.updateAvailability(
                    canImportFoundationModels: true,
                    osAvailable: true,
                    runtimeAvailable: false,
                    failureReason: String(describing: reason)
                )
            }
            return .unavailable(reason: String(describing: reason))
        }
        #else
        Task {
            await NativeLLMDiagnosticsCenter.shared.updateAvailability(
                canImportFoundationModels: false,
                osAvailable: false,
                runtimeAvailable: false,
                failureReason: "FoundationModels framework is not in this SDK"
            )
        }
        return .unavailable(reason: "FoundationModels framework is not in this SDK")
        #endif
    }

    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics {
        await NativeLLMDiagnosticsCenter.shared.snapshot()
    }

    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage {
        let prompt = PromptFactory.replyPrompt(context: context)
        let text = try await generateText(prompt: prompt, characterId: context.character.id, purpose: "reply")
        return ChatMessage(
            sender: .character,
            text: text,
            createdAt: context.now,
            generationMode: generationMode
        )
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        let prompt = PromptFactory.scenarioPrompt(scenario: scenario, context: context)
        let text = try await generateText(prompt: prompt, characterId: context.character.id, purpose: scenario.logTag)
        return ChatMessage(
            sender: .character,
            text: text,
            createdAt: context.now,
            generationMode: generationMode
        )
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        let prompt = PromptFactory.momentPrompt(context: context)
        let text = try await generateText(prompt: prompt, characterId: context.snapshot.character.id, purpose: "moment-\(context.type.rawValue)")
        return MomentMessage(
            id: context.baseMoment.id,
            type: context.baseMoment.type,
            characterName: context.baseMoment.characterName,
            title: context.baseMoment.title,
            body: text,
            scheduledAt: context.baseMoment.scheduledAt,
            isEnabled: context.baseMoment.isEnabled,
            analysisID: context.baseMoment.analysisID,
            generationMode: generationMode
        )
    }

    private func generateText(prompt: String, characterId: UUID, purpose: String) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            let reason = "iOS 26.0+ required"
            print("[NativeLLM] compile canImportFoundationModels=true")
            print("[NativeLLM] osAvailable=false reason=iOS26Required")
            await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
                canImportFoundationModels: true,
                osAvailable: false,
                runtimeAvailable: false,
                contextCharacterCount: prompt.count,
                reason: reason
            )
            throw NativeFoundationModelError.unavailable(reason)
        }

        let model = SystemLanguageModel.default
        print("[NativeLLM] compile canImportFoundationModels=true")
        print("[NativeLLM] osAvailable=true iOS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        switch model.availability {
        case .available:
            print("[NativeLLM] runtimeAvailability=available")
        case .unavailable(let reason):
            let reasonText = String(describing: reason)
            print("[NativeLLM] runtimeAvailability=unavailable reason=\(reasonText)")
            await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
                canImportFoundationModels: true,
                osAvailable: true,
                runtimeAvailable: false,
                contextCharacterCount: prompt.count,
                reason: reasonText
            )
            throw NativeFoundationModelError.unavailable(reasonText)
        }

        print("[NativeLLM] generation=start characterId=\(characterId) purpose=\(purpose) contextChars=\(prompt.count)")
        print("[NativeLLM] promptPolicy=noSensitiveHealthRawData noExternalAPI=true")
        await NativeLLMDiagnosticsCenter.shared.markGenerationStarted(
            canImportFoundationModels: true,
            osAvailable: true,
            runtimeAvailable: true,
            contextCharacterCount: prompt.count
        )

        let session = LanguageModelSession(
            model: model,
            instructions: "Write concise Korean romantic character messages for LoveyMoment. Stay in character. Never mention AI, models, prompts, APIs, diagnostics, policies, hidden state, or external services. Use no sensitive raw health data."
        )
        let text: String
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: 0.7, maximumResponseTokens: 90)
            )
            text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[NativeLLM] generation=failed reason=\(error.localizedDescription)")
            await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
                canImportFoundationModels: true,
                osAvailable: true,
                runtimeAvailable: true,
                contextCharacterCount: prompt.count,
                reason: error.localizedDescription
            )
            throw error
        }
        guard !text.isEmpty else {
            print("[NativeLLM] generation=failed reason=emptyResponse")
            await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
                canImportFoundationModels: true,
                osAvailable: true,
                runtimeAvailable: true,
                contextCharacterCount: prompt.count,
                reason: "emptyResponse"
            )
            throw NativeFoundationModelError.emptyResponse
        }
        print("[NativeLLM] generation=success outputChars=\(text.count) mode=nativeFoundationModel")
        print("[ConversationGenerator] finalMode=nativeFoundationModel noExternalAPI=true")
        await NativeLLMDiagnosticsCenter.shared.markGenerationSucceeded(text: text)
        return text
        #else
        let reason = "FoundationModels framework is not in this SDK"
        print("[NativeLLM] compile canImportFoundationModels=false")
        await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
            canImportFoundationModels: false,
            osAvailable: false,
            runtimeAvailable: false,
            contextCharacterCount: prompt.count,
            reason: reason
        )
        throw NativeFoundationModelError.unavailable(reason)
        #endif
    }
}

actor NativeLLMDiagnosticsCenter {
    static let shared = NativeLLMDiagnosticsCenter()

    private var diagnostics = NativeLLMDiagnostics.empty

    func updateAvailability(
        canImportFoundationModels: Bool,
        osAvailable: Bool,
        runtimeAvailable: Bool,
        failureReason: String?
    ) {
        diagnostics.canImportFoundationModels = canImportFoundationModels
        diagnostics.osAvailable = osAvailable
        diagnostics.runtimeAvailable = runtimeAvailable
        diagnostics.noExternalAPI = true
        if !runtimeAvailable {
            diagnostics.lastGenerationMode = .unavailable
            diagnostics.lastFailureReason = failureReason
        }
    }

    func markGenerationStarted(
        canImportFoundationModels: Bool,
        osAvailable: Bool,
        runtimeAvailable: Bool,
        contextCharacterCount: Int
    ) {
        diagnostics.canImportFoundationModels = canImportFoundationModels
        diagnostics.osAvailable = osAvailable
        diagnostics.runtimeAvailable = runtimeAvailable
        diagnostics.contextCharacterCount = contextCharacterCount
        diagnostics.lastGenerationStartedAt = Date()
        diagnostics.lastGenerationCompletedAt = nil
        diagnostics.lastGenerationSucceeded = false
        diagnostics.lastFailureReason = nil
        diagnostics.lastFallbackReason = nil
        diagnostics.lastGeneratedCharacterCount = 0
        diagnostics.lastGeneratedTextPreview = nil
        diagnostics.lastGenerationMode = .nativeFoundationModel
        diagnostics.noExternalAPI = true
    }

    func markGenerationSucceeded(text: String) {
        diagnostics.runtimeAvailable = true
        diagnostics.lastGenerationCompletedAt = Date()
        diagnostics.lastGenerationSucceeded = true
        diagnostics.lastFailureReason = nil
        diagnostics.lastFallbackReason = nil
        diagnostics.lastGeneratedCharacterCount = text.count
        diagnostics.lastGeneratedTextPreview = String(text.prefix(80))
        diagnostics.lastGenerationMode = .nativeFoundationModel
        diagnostics.noExternalAPI = true
    }

    func markGenerationFailed(
        canImportFoundationModels: Bool,
        osAvailable: Bool,
        runtimeAvailable: Bool,
        contextCharacterCount: Int,
        reason: String
    ) {
        diagnostics.canImportFoundationModels = canImportFoundationModels
        diagnostics.osAvailable = osAvailable
        diagnostics.runtimeAvailable = runtimeAvailable
        diagnostics.contextCharacterCount = contextCharacterCount
        diagnostics.lastGenerationCompletedAt = Date()
        diagnostics.lastGenerationSucceeded = false
        diagnostics.lastFailureReason = reason
        diagnostics.lastGeneratedCharacterCount = 0
        diagnostics.lastGeneratedTextPreview = nil
        diagnostics.lastGenerationMode = .unavailable
        diagnostics.noExternalAPI = true
    }

    func markFallback(reason: String) {
        diagnostics.lastGenerationCompletedAt = Date()
        diagnostics.lastGenerationSucceeded = false
        diagnostics.lastFallbackReason = reason
        diagnostics.lastGenerationMode = .localDeterministicFallback
        diagnostics.noExternalAPI = true
    }

    func snapshot() -> NativeLLMDiagnostics {
        diagnostics
    }
}

enum NativeFoundationModelError: Error, LocalizedError {
    case unavailable(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .emptyResponse: return "Native Foundation Model returned an empty response."
        }
    }
}

private enum PromptFactory {
    static func replyPrompt(context: ConversationGenerationContext) -> String {
        """
        LoveyMoment 채팅 답장 1개만 한국어로 작성해.
        캐릭터: \(context.character.name), \(context.character.personalitySummary)
        캐릭터 말투 키워드: \(context.character.defaultToneKeywords.joined(separator: ", "))
        세계관: \(context.world.title) / \(context.world.summary)
        관계: \(context.relationshipStage.label), \(context.relationshipStage.description)
        최근 장면: \(context.lastSceneSummary)
        시간대: \(timeBucket(context.now))
        수면 신호: \(sleepSummary(context.sleepSignal))
        최근 대화:
        \(recentMessages(context.messages))

        조건:
        - 1~3문장
        - 채팅 말풍선에 맞는 짧고 자연스러운 길이
        - 캐릭터 말투 유지
        - 여성향 캐릭터 앱의 남자 캐릭터처럼 말하기
        - 유저를 과하게 압박하지 않기
        - 미성년 캐릭터처럼 보일 수 있는 설정이면 선정적이거나 노골적인 표현 금지
        - 수면/건강 데이터 숫자, source, confidence, 내부 진단 상태를 직접 말하지 않기
        - "나는 AI야", "모델로서", "API", "프롬프트" 같은 표현 금지
        """
    }

    static func scenarioPrompt(scenario: ConversationScenario, context: ConversationGenerationContext) -> String {
        """
        \(scenario.title) 상황에 맞는 캐릭터 메시지 1개만 한국어로 작성해.
        캐릭터: \(context.character.name), \(context.character.defaultToneKeywords.joined(separator: ", "))
        세계관 키워드: \(context.world.sceneKeywords.joined(separator: ", "))
        관계 단계: \(context.relationshipStage.progressHint)
        수면 신호: \(sleepSummary(context.sleepSignal))
        최근 대화:
        \(recentMessages(context.messages))

        조건:
        - 1~2문장
        - 설명문이 아니라 캐릭터가 직접 보내는 말풍선처럼 쓰기
        - 과한 확정 고백 금지
        - 수면/건강 데이터 숫자, source, confidence를 직접 말하지 않기
        - 캐릭터가 실제 알림/분석 시스템을 알고 있는 것처럼 쓰지 않기
        - "나는 AI야", "모델로서", "API", "프롬프트" 같은 표현 금지
        """
    }

    static func momentPrompt(context: MomentGenerationContext) -> String {
        """
        \(context.type.displayName) 로컬 알림 본문 1개만 한국어로 작성해.
        캐릭터: \(context.snapshot.character.name), \(context.snapshot.character.personalitySummary)
        세계관: \(context.snapshot.worldSetting.title)
        관계: \(context.snapshot.relationshipStage.label), \(context.snapshot.relationshipStage.allowedToneRange)
        시간대: \(context.type == .bedtime ? "bedtime" : "morning")
        Moment 설정: bedtime=\(context.momentSettings.isBedtimeMomentEnabled), morning=\(context.momentSettings.isMorningMomentEnabled), mode=\(context.momentSettings.notificationMode.rawValue)
        수면 신호 요약: \(sleepSummary(context.sleepSignal))
        분석 요약: \(context.analysisSummary)
        최근 대화:
        \(recentMessages(context.snapshot.recentMessages))

        조건:
        - \(context.type == .bedtime ? "잠들기 전 끊긴 장면을 다시 여는 느낌" : "아침에 다시 대화가 이어지는 느낌")
        - 캐릭터가 먼저 말을 거는 느낌
        - 1~2문장, 45자 이내 권장
        - 알림 본문처럼 바로 읽히게 쓰기
        - 수면/건강 데이터 숫자를 직접 말하지 않기
        - 건강 앱, HealthKit, Native LLM, AI, API라는 단어 쓰지 않기
        """
    }

    private static func recentMessages(_ messages: [ChatMessage]) -> String {
        messages.suffix(10).map { message in
            let role: String
            switch message.sender {
            case .user: role = "user"
            case .character: role = "character"
            case .system: role = "system"
            }
            return "- \(role): \(message.text)"
        }
        .joined(separator: "\n")
    }

    private static func sleepSummary(_ signal: SleepSignal?) -> String {
        guard let signal else { return "없음" }
        let sourceText = signal.source == .healthKit ? "실제 수면 신호 기반" : "fallback 수면 신호 기반"
        return "\(sourceText), confidence=\(signal.confidence.rawValue), 자연스럽게 컨디션만 반영하고 시간 숫자는 말하지 않기"
    }

    private static func timeBucket(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0...4: return "dawn"
        case 5...10: return "morning"
        case 11...17: return "afternoon"
        case 18...21: return "evening"
        default: return "bedtime"
        }
    }
}
