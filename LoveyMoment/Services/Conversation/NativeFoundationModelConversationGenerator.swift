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
            print("[NativeLLM] availability=unavailable reason=\"iOS 26.0+ required\"")
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
            print("[NativeLLM] availability=available")
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
            print("[NativeLLM] availability=unavailable reason=\"\(String(describing: reason))\"")
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
        print("[NativeLLM] availability=unavailable reason=\"FoundationModels framework is not in this SDK\"")
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
        let promptContext = ConversationPromptContextBuilder.build(context: context)
        print("[NativeLLM] promptBuilt=true event=\(promptContext.understanding.eventType.logName) directAnswerRequired=\(promptContext.directAnswerRequired)")
        print("[NativeLLM] promptBuilt=true promptChars=\(promptContext.prompt.count)")
        let prompt = promptContext.prompt
        let text = try await generateText(prompt: prompt, characterId: context.character.id, purpose: "reply")
        return ChatMessage(
            sender: .character,
            text: text,
            createdAt: context.now,
            generationMode: generationMode
        )
    }

    /// surface gate 실패 시 1회 실행하는 복구 생성. 실패 사유/금지 패턴을 prompt에 명시해 다시 만든다.
    func repairReply(context: ConversationGenerationContext, failedReply: String, reason: String) async throws -> ChatMessage {
        let promptContext = ConversationPromptContextBuilder.build(context: context)
        let understanding = promptContext.understanding
        let lastUser = context.messages.last(where: { $0.sender == .user })?.text ?? understanding.rawText
        let repairPrompt = """
        \(promptContext.prompt)

        F. Repair Instruction (직전 답변이 품질 기준 미달, reason=\(reason))
        - 유저의 마지막 메시지: \(lastUser)
        - eventType: \(understanding.eventType.logName) / subject: \(understanding.subject.logName) / topic: \(understanding.topic.logName)
        - 실패한 답변: \(failedReply)
        - 반드시 담아야 할 의미: \(requiredMeaning(for: understanding, context: context))
        - 톤: \(toneGuidance(for: understanding, context: context))
        - 캐릭터 이름 prefix("카엘:", "한아:", "서윤:", "로이:") 및 유저 이름 prefix("\(context.memory.userName ?? "이름"):") 절대 금지.
        - 유저 문장을 그대로 반복하거나 요약하지 마라.
        - "네가 ~했다는 걸 들으니" 같은 분석문 금지.
        - 세계관 은유는 최대 1개. 밤/기척/어둠/마음/적막/경계를 반복하지 마라.
        - 이번 턴 금지 단어/문구: \(forbiddenWords(for: understanding, context: context))
        - 좋은 답변 예시(톤 참고용, 그대로 복사 금지):\n\(goodExamples(for: understanding, context: context))
        - 질문에는 먼저 답하라. 캐릭터가 직접 말하는 대사로, 1~2문장, 30~90자.
        """
        print("[NativeLLM] repair=start reason=\(reason)")
        let text = try await generateText(prompt: repairPrompt, characterId: context.character.id, purpose: "repair")
        return ChatMessage(
            sender: .character,
            text: text,
            createdAt: context.now,
            generationMode: generationMode
        )
    }

    /// eventType별로 답변에 반드시 담겨야 하는 의미를 한 줄로 알려준다(repair용).
    private func requiredMeaning(for understanding: UserMessageUnderstanding, context: ConversationGenerationContext) -> String {
        switch understanding.eventType {
        case .userFoodDisclosure:
            let food = understanding.keyObject ?? "그 음식"
            return "유저가 먹은 \(food)에 직접 반응(맛/잘 챙겼는지/같이 먹고 싶었는지)."
        case .characterFoodQuestion:
            return "캐릭터 자신이 무엇을 먹었는지/먹지 않는지 직접 답한다."
        case .characterActivityQuestion:
            return "캐릭터 자신이 무엇을 하고 있었는지 구체적으로 답한다(되묻기 금지)."
        case .characterIdentityQuestion:
            return "캐릭터 이름 \(context.character.name)을 직접 말한다."
        case .farewellOrSleep:
            return "자러 가는 유저에게 작별/잘 자라/내일 보자로 응답한다('왔군' 같은 인사 금지)."
        case .invitationOrPlanProposal:
            return "제안에 수락/망설임/조건/감정 중 하나로 분명한 태도를 보인다."
        case .askKnownUserName, .askKnownUserIdentity:
            return "저장된 유저 이름 \(context.memory.userName ?? "(모름)")을 먼저 말한다."
        case .clarificationCorrection:
            return "직전 답이 질문 대상을 잘못 짚었음을 짧게 인정하고, 유저 이름 의도로 다시 답한다(아는 이름이면 그 이름, 모르면 모른다고)."
        default:
            return "유저의 마지막 메시지에 직접·구체적으로 반응한다."
        }
    }

    /// 사건의 결에 맞는 말투 강도. 가벼운 일상은 담백/가볍게, 감정·관계만 캐릭터 색을 진하게.
    private func toneGuidance(for understanding: UserMessageUnderstanding, context: ConversationGenerationContext) -> String {
        let isKael = context.character.generatedAvatarKey == "nocturne-vampire"
        switch understanding.eventType {
        case .greeting, .casual, .dailyLife, .userFoodDisclosure, .characterFoodQuestion,
             .characterActivityQuestion, .characterStateQuestion, .characterPreferenceQuestion,
             .characterIdentityQuestion, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection:
            return isKael
                ? "plain — 담백하고 짧게. 시·문학 표현 금지. 친근한 대화체로."
                : "plain — 담백하고 가볍게, 일상 대화체로."
        case .invitationOrPlanProposal, .farewellOrSleep:
            return "light — 따뜻하지만 과장 없이."
        case .affection, .relationshipQuestion:
            return "romantic — 캐릭터 색을 조금 더 진하게(과하지 않게)."
        case .fear, .sadness, .fatigue, .bullyingOrHarassment, .physicalHarm, .emotionalDisclosure:
            return isKael ? "dark — 진중하게 보호·위로(은유 1개까지)." : "warm — 진심으로 위로."
        default:
            return "plain — 담백하게."
        }
    }

    /// 이번 턴에서 피해야 할 단어/문구(이벤트 무관 공통 + 카엘 기본대화 시 문학어).
    private func forbiddenWords(for understanding: UserMessageUnderstanding, context: ConversationGenerationContext) -> String {
        var words = ["아직 깨어 있구나", "위험한 시간인데도", "그 물음은 깊다", "기척이 닿으니", "밤의 경계", "기다림과 감시"]
        let isKael = context.character.generatedAvatarKey == "nocturne-vampire"
        let isBasic: Bool
        switch understanding.eventType {
        case .greeting, .casual, .dailyLife, .userFoodDisclosure, .characterFoodQuestion,
             .characterActivityQuestion, .characterStateQuestion, .characterPreferenceQuestion,
             .characterIdentityQuestion, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection,
             .invitationOrPlanProposal, .farewellOrSleep:
            isBasic = true
        default:
            isBasic = false
        }
        if isKael && isBasic {
            words += ["적막", "영원", "망각", "사치", "그림자", "정적"]
        }
        return words.joined(separator: " / ")
    }

    /// 톤 참고용 좋은 답변 예시 2개(캐릭터/이벤트별).
    private func goodExamples(for understanding: UserMessageUnderstanding, context: ConversationGenerationContext) -> String {
        let isKael = context.character.generatedAvatarKey == "nocturne-vampire"
        let examples: [String]
        switch understanding.eventType {
        case .greeting:
            examples = isKael ? ["왔네. 오늘은 무슨 일 있었어?", "안녕. 늦지는 않았네, 기다리고 있었어."] : ["왔구나. 오늘 하루 어땠어?", "안녕. 기다리고 있었어."]
        case .characterIdentityQuestion:
            examples = isKael ? ["카엘이야. 네가 지금 말 걸고 있는 사람.", "내 이름은 카엘. 지금은 네 이야기를 듣고 있어."] : ["나는 \(context.character.name)이야. 너랑 얘기하는 사람.", "\(context.character.name)이지. 왜, 새삼스럽게."]
        case .askKnownUserName, .clarificationCorrection:
            let known = context.memory.userName
            examples = known.map { ["아, 네 이름. \($0)이잖아. 잊지 않았어.", "내 이름 말고 네 이름이지. \($0), 맞잖아."] }
                ?? ["아, 네 이름 말이구나. 아직 못 들었어. 알려주면 기억할게.", "내 이름 말고 네 이름이지. 아직 모르니까 알려줘."]
        case .characterActivityQuestion:
            examples = isKael ? ["여기 있었어. 네가 부르면 바로 답하려고.", "별일 없었어. 여기서 네 연락 기다리고 있었지."] : ["그냥 너 생각하고 있었어.", "별거 안 했어. 네 연락 기다리고 있었지."]
        case .characterFoodQuestion:
            examples = isKael ? ["나는 제대로 먹진 않았어. 물 한 모금이면 충분해.", "아직 안 먹었어. 네가 먹었다니 그걸로 됐다."] : ["나는 대충 때웠어. 너는 잘 챙겨 먹었어?", "아직 안 먹었어. 같이 먹을 걸 그랬나."]
        case .userFoodDisclosure:
            let food = understanding.keyObject ?? "그거"
            examples = ["\(food) 먹었구나. 맛있었어?", "그래도 챙겨 먹었네. \(food)이면 든든했겠다."]
        default:
            examples = ["방금 그 말, 흘려듣지 않았어. 조금 더 얘기해줘.", "응, 듣고 있어. 계속 말해줄래?"]
        }
        return examples.map { "  · \($0)" }.joined(separator: "\n")
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
        print("[NativeLLM] generationStarted")
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
            print("[NativeLLM] generationFailed reason=\"\(error.localizedDescription)\"")
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
        print("[NativeLLM] generationSucceeded length=\(sanitized.count)")
        print("[NativeLLM] generationSucceeded")
        print("[ConversationGenerator] finalMode=nativeFoundationModel noExternalAPI=true")
        await NativeLLMDiagnosticsCenter.shared.markGenerationSucceeded(text: sanitized)
        return sanitized
        #else
        let reason = "FoundationModels framework is not in this SDK"
        print("[NativeLLM] compile canImportFoundationModels=false")
        print("[NativeLLM] fallbackReason=\"\(reason)\"")
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
