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
        print("[NativeLLM] rawOutput=\(text)")
        let sanitized: String
        do {
            sanitized = try ConversationOutputSanitizer.sanitize(text)
        } catch let error as ConversationOutputSanitizer.SanitizerError {
            print("[NativeLLM] fallback=localDeterministicFallback reason=sanitizerRejected:\(error.reason.rawValue)")
            await NativeLLMDiagnosticsCenter.shared.markGenerationFailed(
                canImportFoundationModels: true,
                osAvailable: true,
                runtimeAvailable: true,
                contextCharacterCount: prompt.count,
                reason: "sanitizerRejected:\(error.reason.rawValue)"
            )
            throw NativeFoundationModelError.sanitizerRejected(error.reason.rawValue)
        }
        print("[NativeLLM] generation=success outputChars=\(sanitized.count) mode=nativeFoundationModel")
        print("[ConversationGenerator] finalMode=nativeFoundationModel noExternalAPI=true")
        await NativeLLMDiagnosticsCenter.shared.markGenerationSucceeded(text: sanitized)
        return sanitized
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
    case sanitizerRejected(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .emptyResponse: return "Native Foundation Model returned an empty response."
        case .sanitizerRejected(let reason): return "Native output rejected by sanitizer: \(reason)"
        }
    }
}

private enum PromptFactory {
    static func replyPrompt(context: ConversationGenerationContext) -> String {
        """
        너는 \(context.character.name)라는 캐릭터다. 지금 좋아하는 상대에게 채팅으로 답장을 보낸다.
        성격: \(context.character.personalitySummary)
        말투: \(context.character.defaultToneKeywords.joined(separator: ", "))
        관계: \(context.relationshipStage.label) (\(context.relationshipStage.description))
        지금 분위기: \(timeBucket(context.now)), \(sleepSummary(context.sleepSignal))
        직전 대화:
        \(recentMessages(context.messages))

        \(outputRules)
        - 직전 상대 말의 내용과 감정에 직접 반응해서 자연스럽게 이어간다
        - 대화가 끊기지 않게, 가벼운 질문 하나나 감정 한 줄로 마무리한다
        - 1~2문장, 80자 이내, 캐릭터 말투 그대로 다정하게
        - 유저를 과하게 압박하거나 설명하듯 말하지 않기
        """
    }

    static func scenarioPrompt(scenario: ConversationScenario, context: ConversationGenerationContext) -> String {
        """
        너는 \(context.character.name)라는 캐릭터다. 지금 좋아하는 상대에게 먼저 채팅을 보낸다.
        상황: \(scenario.title)
        말투: \(context.character.defaultToneKeywords.joined(separator: ", "))
        장면 키워드: \(context.world.sceneKeywords.joined(separator: ", "))
        관계 단계: \(context.relationshipStage.progressHint)
        지금 분위기: \(sleepSummary(context.sleepSignal))
        직전 대화:
        \(recentMessages(context.messages))

        \(outputRules)
        - 1~2문장, 80자 이내
        - 캐릭터가 직접 보내는 말풍선 한 줄
        - 과한 확정 고백 금지
        """
    }

    static func momentPrompt(context: MomentGenerationContext) -> String {
        """
        너는 \(context.snapshot.character.name)라는 캐릭터다. \(context.type == .bedtime ? "상대가 잠들기 전" : "상대가 깨어난 아침")에 먼저 짧은 알림 메시지를 보낸다.
        성격: \(context.snapshot.character.personalitySummary)
        관계: \(context.snapshot.relationshipStage.label) (\(context.snapshot.relationshipStage.allowedToneRange))
        지금 분위기: \(sleepSummary(context.sleepSignal))
        직전 대화:
        \(recentMessages(context.snapshot.recentMessages))

        \(outputRules)
        - \(context.type == .bedtime ? "잠들기 전 끊긴 장면을 다시 여는 느낌" : "아침에 대화가 다시 이어지는 느낌")
        - 캐릭터가 먼저 말을 거는 한 줄
        - 1~2문장, 45자 이내
        - 알림에 떠도 자연스럽게
        """
    }

    /// 모든 출력에 공통으로 강제하는 형식 규칙. 선택지/예시/목록/markdown을 절대 만들지 않게 한다.
    private static let outputRules = """
    형식 규칙(반드시 지킬 것):
    - 캐릭터가 보내는 메시지 딱 한 개만 출력한다
    - 여러 개를 만들거나, 후보를 나열하지 않는다
    - 번호(1. 2.), 불릿(-, *), 제목, 설명, 따옴표를 쓰지 않는다
    - 굵게/markdown 표기를 쓰지 않는다
    - "예시", "답장", "메시지", "보기" 같은 단어로 시작하지 않는다
    - 수면/건강 데이터의 숫자, source, confidence, 내부 분석 상태를 직접 말하지 않는다
    - AI, 모델, 프롬프트, API라는 말을 쓰지 않는다
    - 오직 캐릭터의 대사 문장만 출력한다
    """

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
