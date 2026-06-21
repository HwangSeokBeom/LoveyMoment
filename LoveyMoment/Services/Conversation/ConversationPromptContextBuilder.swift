import Foundation

struct ConversationPromptContext {
    let prompt: String
    let understanding: UserMessageUnderstanding
    let bible: CharacterDialogueBible
    let recentMessages: [ChatMessage]
    let hasBible: Bool
    let hasWorld: Bool
    let hasMemory: Bool
    let hasRecentMessages: Bool
    let directAnswerRequired: Bool
}

enum ConversationPromptContextBuilder {
    static func build(context: ConversationGenerationContext) -> ConversationPromptContext {
        let userMessages = context.messages.filter { $0.sender == .user }
        let lastUser = userMessages.last?.text ?? ""
        let previousUser = userMessages.count >= 2 ? userMessages[userMessages.count - 2].text : ""
        let previousCharacter = context.messages.last(where: { $0.sender == .character })?.text ?? ""
        let understanding = UserMessageUnderstandingAnalyzer.analyze(
            userLastMessage: lastUser,
            previousUserMessage: previousUser,
            previousCharacterMessage: previousCharacter,
            avatarKey: context.character.generatedAvatarKey,
            knownUserName: context.memory.userName
        )
        let bible = CharacterDialogueBible.bible(for: context.character.generatedAvatarKey)
        let recent = Array(context.messages.suffix(14))
        let hasWorld = !context.world.summary.isEmpty || !context.world.sceneKeywords.isEmpty
        let hasMemory = context.memory.userName != nil
            || context.memory.lastUserSelfIntroduction != nil
            || !context.memory.knownFacts.isEmpty
            || !context.memory.previousUserNames.isEmpty
        let prompt = promptText(
            context: context,
            bible: bible,
            understanding: understanding,
            recent: recent,
            hasMemory: hasMemory
        )

        let built = ConversationPromptContext(
            prompt: prompt,
            understanding: understanding,
            bible: bible,
            recentMessages: recent,
            hasBible: true,
            hasWorld: hasWorld,
            hasMemory: hasMemory,
            hasRecentMessages: !recent.isEmpty,
            directAnswerRequired: understanding.requiresDirectAnswer
        )
        log(built: built, character: context.character)
        return built
    }

    private static func promptText(
        context: ConversationGenerationContext,
        bible: CharacterDialogueBible,
        understanding: UserMessageUnderstanding,
        recent: [ChatMessage],
        hasMemory: Bool
    ) -> String {
        """
        LoveyMoment on-device character chat prompt.

        A. Character Bible
        - name: \(bible.name)
        - genre: \(context.character.stats.genreLabel.isEmpty ? bible.world : context.character.stats.genreLabel)
        - identity: \(bible.role)
        - world: \(bible.world) / \(context.world.title) / \(context.world.summary)
        - relationshipStage: \(context.relationshipStage.label) / \(context.relationshipStage.description)
        - speechStyle:
          - \(bible.speechStyle)
          - 짧고 깊게 말함
          - 직접 답변을 먼저 함
          - 세계관 은유는 한 문장 안에서 절제
          - 질문 회피 금지
          - 상담사처럼 길게 설명 금지
        - emotionalCore: \(bible.emotionalCore)
        - boundaries:
          - \(bible.dontList.joined(separator: "\n  - "))
        - directAnswerPolicy: 질문에는 먼저 답한다. 기억 질문에는 저장된 값을 말한다. 세계관 말투는 답변 뒤에만 입힌다. 시적 회피 금지.

        B. Conversation Memory
        - userName: \(context.memory.userName ?? "unknown")
        - previousUserNames: \(context.memory.previousUserNames.isEmpty ? "none" : context.memory.previousUserNames.joined(separator: ", "))
        - recentCorrection: \(context.memory.lastNameUpdateReason ?? "none")
        - lastNameUpdateReason: \(context.memory.lastNameUpdateReason ?? "none")
        - recentSceneSummary: \(context.memory.recentSceneSummary ?? context.lastSceneSummary)
        - relationshipHints: \(context.memory.relationshipHints.isEmpty ? "none" : context.memory.relationshipHints.joined(separator: "; "))
        - knownFacts: \(context.memory.knownFacts.isEmpty ? "none" : context.memory.knownFacts.joined(separator: "; "))
        - lastSelfIntroduction: \(context.memory.lastUserSelfIntroduction ?? "none")
        - unresolvedUserConcern: \(unresolvedConcern(context: context, understanding: understanding))
        - hasMemory: \(hasMemory)

        C. Recent Messages (backgroundOnly)
        Rules:
        - These are reference context only, NOT the current request.
        - Use only real user/assistant turns below.
        - Treat system rows as app state, not as the user's newest request.
        - Do not re-answer or re-evaluate an earlier user turn. Answer ONLY the latest user message in section D.
        - Do not copy old seed/demo wording.
        \(recentMessagesText(recent))

        D. Current Turn Understanding (HIGHEST PRIORITY)
        - latestUserMessage: \(understanding.rawText)
        - eventType: \(understanding.eventType.logName)
        - subject: \(understanding.subject.logName)
        - target: \(understanding.target.logName)
        - topic: \(understanding.topic.logName)
        - extractedName: \(understanding.extractedUserName ?? "none")
        - knownName: \(understanding.knownUserName ?? "none")
        - directAnswerRequired: \(understanding.requiresDirectAnswer)
        - emotion: \(understanding.emotion ?? "none")
        - safetyLevel: \(safetyLevel(understanding.severity))
        - isCorrection: \(understanding.eventType == .userNameCorrection)
        - isFollowUpQuestion: \(isFollowUpQuestion(understanding))
        - keyObject: \(understanding.keyObject ?? "none")
        Turn rules:
        - subject=character 이면(예: "너는 뭐 먹었어?") 직전 유저 발화가 아니라 \(bible.name) 자신(음식/활동/취향/상태)에 대해 답한다.
        - subject=user 이면 유저가 방금 알린 내용에 직접 반응한다.
        - 최근 대화(C)는 참고만 한다. 직전 유저 발화를 다시 평가하지 않는다.
        - eventContract: \(eventContract(understanding: understanding, bible: bible, context: context))

        E. Response Contract (Surface Rules)
        - 한국어
        - 1~2문장
        - 30~90자
        - 캐릭터 이름 prefix를 붙이지 마라. 예: "\(bible.name):" 절대 금지. 말풍선엔 대사만 들어간다.
        - 유저 말을 그대로 반복하거나 요약하지 마라. "내일 놀이동산가자" 같은 제안을 똑같이 따라 말하지 마라.
        - "네가 ~했다는 걸 들으니", "그 이야기를 들으니" 같은 분석문/설명문 금지. 캐릭터가 직접 말하는 대사로만.
        - 첫 문장은 유저의 마지막 메시지에 대한 직접 반응이어야 한다.
        - 제안/초대(놀이동산/데이트/여행/같이 가자 등)에는 수락/망설임/조건/감정 중 하나로 답하라. 동문서답 금지.
        - 질문에는 먼저 답한다. known memory가 있으면 반드시 사용한다.
        - 세계관 은유는 직접 답변 이후에만, 한 문장 안에서 1개까지. \(bible.name)이면 밤/기척/어둠/마음을 매 답변마다 반복하지 마라.
        - 캐릭터 말투 유지. 목록/설명문/AI 언급 금지.
        - 이전 답변과 같은 구조 반복 금지.
        - 모르면 모른다고 말하고 무엇을 알려주면 되는지 묻기.
        - generic poetic filler 금지.
        """
    }

    /// eventType별로 반드시 지켜야 하는 응답 계약을 한 줄로 만든다.
    private static func eventContract(
        understanding: UserMessageUnderstanding,
        bible: CharacterDialogueBible,
        context: ConversationGenerationContext
    ) -> String {
        switch understanding.eventType {
        case .userFoodDisclosure:
            let food = understanding.keyObject ?? "그 음식"
            return "유저가 먹은 \(food)에 직접 반응해라(맛/잘 챙겼는지/같이 먹고 싶었는지). 밤·위험·책임 얘기로 새지 마라."
        case .characterFoodQuestion:
            return "\(bible.name) 자신이 무엇을 먹었는지/먹지 않는지 직접 답해라."
        case .characterActivityQuestion:
            return "\(bible.name) 자신이 지금 무엇을 하고 있었는지 구체적으로 답해라. 유저에게 되묻지 마라."
        case .characterIdentityQuestion:
            return "\(bible.name)이라고 이름을 직접 말해라. 추상적 회피 금지."
        case .farewellOrSleep:
            return "자러 가는 유저에게 작별/잘 자라/내일 보자로 답해라. '왔군' 같은 인사로 받지 마라."
        case .invitationOrPlanProposal:
            return "제안에 수락/망설임/조건/감정 중 하나로 분명한 태도를 보여라. 제안을 그대로 따라 말하지 마라."
        case .askKnownUserName, .askKnownUserIdentity:
            return "저장된 유저 이름 \(context.memory.userName ?? "(모름)")을 먼저 말해라."
        default:
            return "유저의 마지막 메시지에 직접·구체적으로 반응해라."
        }
    }

    private static func recentMessagesText(_ messages: [ChatMessage]) -> String {
        guard !messages.isEmpty else { return "- none" }
        return messages.map { message in
            let role: String
            switch message.sender {
            case .user: role = "user"
            case .character: role = "assistant"
            case .system: role = "system"
            }
            return "- \(role): \(message.text)"
        }
        .joined(separator: "\n")
    }

    private static func safetyLevel(_ severity: EventSeverity) -> String {
        switch severity {
        case .none: return "none"
        case .elevated: return "elevated"
        case .safety: return "safety"
        }
    }

    private static func isFollowUpQuestion(_ understanding: UserMessageUnderstanding) -> Bool {
        understanding.rawText.contains("?")
            || understanding.rawText.hasSuffix("까")
            || understanding.rawText.contains("뭐")
            || understanding.rawText.contains("왜")
            || understanding.rawText.contains("어떻게")
    }

    private static func unresolvedConcern(context: ConversationGenerationContext, understanding: UserMessageUnderstanding) -> String {
        if understanding.severity == .safety {
            return "userSafetyOrHarm"
        }
        if let emotion = understanding.emotion {
            return "emotion=\(emotion)"
        }
        let recent = context.messages.suffix(4).map(\.text).joined(separator: " ")
        if recent.contains("무서") { return "fear" }
        if recent.contains("잠이 안") || recent.contains("잠 안") { return "sleeplessness" }
        if recent.contains("맛은 없") { return "disappointedFood" }
        return "none"
    }

    private static func log(built: ConversationPromptContext, character: CharacterProfile) {
        let key = characterLogKey(character.generatedAvatarKey)
        let knownName = built.understanding.knownUserName ?? "nil"
        print("[PromptContext] hasCharacterBible=\(built.hasBible) hasWorld=\(built.hasWorld) hasMemory=\(built.hasMemory) hasRecentMessages=\(built.hasRecentMessages)")
        print("[PromptContext] character=\(key) hasBible=\(built.hasBible) hasMemory=\(built.hasMemory) hasRecentMessages=\(built.hasRecentMessages) recentCount=\(built.recentMessages.count)")
        print("[PromptContext] event=\(built.understanding.eventType.logName) subject=\(built.understanding.subject.logName) target=\(built.understanding.target.logName) topic=\(built.understanding.topic.logName) knownName=\"\(knownName)\" directAnswerRequired=\(built.directAnswerRequired)")
        print("[PromptContext] recentMessagesRole=backgroundOnly recentCount=\(built.recentMessages.count)")
        print("[PromptContext] surfaceRules=noPrefix,noParroting,directSpeech,limitedWorldFlavor")
        print("[PromptContext] directAnswerRequired=\(built.directAnswerRequired)")
        print("[NativeLLM] promptBuilt=true promptChars=\(built.prompt.count)")
        print("[LLMPrompt] character=\(key) hasBible=\(built.hasBible) hasWorld=\(built.hasWorld) hasMemory=\(built.hasMemory) hasRecentMessages=\(built.hasRecentMessages)")
    }

    private static func characterLogKey(_ avatarKey: String) -> String {
        switch avatarKey {
        case "ice-boss": return "hana"
        case "sunny-friend": return "seoyun"
        case "puppy-junior": return "roi"
        case "nocturne-vampire": return "kael"
        default: return avatarKey
        }
    }
}
