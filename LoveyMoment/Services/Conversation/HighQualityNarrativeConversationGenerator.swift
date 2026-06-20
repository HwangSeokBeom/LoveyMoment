import Foundation

/// 캐릭터·세계관·관계 단계·최근 대화 맥락을 조합해 "스토리 대화" 수준의 답장을 만드는 결정형 고품질 생성기.
/// 유저의 마지막 메시지를 사건(EventType) 단위로 먼저 이해(UserMessageUnderstanding)하고,
/// 캐릭터 바이블(CharacterDialogueBible)의 말투/세계관/관계 결을 반영한 후보만 골라 반환한다.
/// 후보는 사건 인지 품질 평가기를 통과해야 하며, 모두 실패하면 casual이 아니라
/// "그 사건에 직접 반응하는" event-specific fallback을 반환한다. 그래서 질문 회피/무관 응답이 구조적으로 나올 수 없다.
/// 실제 서비스에서는 이 자리에 서버 LLM 오케스트레이션 + 장기 메모리 + 안전 필터가 들어가고,
/// PoC에서는 그 품질을 결정형 내러티브 엔진으로 시뮬레이션한다(온디바이스 구현 자체가 목표가 아님).
struct HighQualityNarrativeConversationGenerator: ConversationGenerating {
    let generationMode: ConversationGenerationMode = .highQualityAssistant
    let compileAvailability = false

    private let planner = StoryReplyPlanner()

    func availabilityStatus() -> ConversationGenerationAvailability { .available }

    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics {
        var diagnostics = NativeLLMDiagnostics.empty
        diagnostics.lastGenerationMode = .highQualityAssistant
        return diagnostics
    }

    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage {
        let flow = StoryConversationFlow(context: context)
        let text = planner.reply(for: flow, context: context)
        return ChatMessage(sender: .character, text: text, createdAt: context.now, generationMode: generationMode)
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        let flow = StoryConversationFlow(context: context)
        let text = planner.scenarioReply(scenario: scenario, flow: flow)
        return ChatMessage(sender: .character, text: text, createdAt: context.now, generationMode: generationMode)
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        let scenario: ConversationScenario = context.type == .bedtime ? .bedtime : .morning
        let text = planner.momentBody(
            avatarKey: context.snapshot.character.generatedAvatarKey,
            scenario: scenario,
            seed: context.snapshot.character.id.uuidString + scenario.rawValue + context.type.rawValue
        )
        .replacingOccurrences(of: "{name}", with: context.snapshot.character.name)
        .replacingOccurrences(of: "{bedtime}", with: context.sleepSignal.estimatedBedtime)
        .replacingOccurrences(of: "{wake}", with: context.sleepSignal.estimatedWakeTime)
        .replacingOccurrences(of: "{place}", with: context.snapshot.worldSetting.sceneKeywords.first ?? context.snapshot.worldSetting.title)
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
}

// MARK: - Flow snapshot (boosted context)

/// 답장을 만들 때 참고하는, 흐름을 담은 경량 컨텍스트.
/// ConversationGenerationContext를 그대로 두고, 답장에 필요한 흐름 신호만 뽑아 보강한다.
struct StoryConversationFlow {
    let avatarKey: String
    let characterName: String
    let relationshipLabel: String
    let userLastMessage: String
    /// 직전 캐릭터 발화. 답장이 앞 발화와 모순/중복되지 않도록 참고한다.
    let previousCharacterMessage: String
    let bedtime: String
    let wakeTime: String
    let place: String
    let mood: ConversationMood
    let seed: String

    init(context: ConversationGenerationContext) {
        avatarKey = context.character.generatedAvatarKey
        characterName = context.character.name
        relationshipLabel = context.relationshipStage.label
        userLastMessage = context.messages.last(where: { $0.sender == .user })?.text ?? ""
        previousCharacterMessage = context.messages.last(where: { $0.sender == .character })?.text ?? ""
        bedtime = context.sleepSignal?.estimatedBedtime ?? "23:40"
        wakeTime = context.sleepSignal?.estimatedWakeTime ?? "07:20"
        place = context.world.sceneKeywords.first ?? context.world.title
        mood = ConversationMood.infer(from: context.messages)
        seed = context.character.id.uuidString
            + context.relationshipStage.label
            + userLastMessage
            + previousCharacterMessage
    }
}

/// 최근 대화의 전반적 분위기. 같은 행위라도 톤을 살짝 다르게 고르는 데 쓴다.
enum ConversationMood {
    case tender
    case playful
    case tense
    case neutral

    static func infer(from messages: [ChatMessage]) -> ConversationMood {
        let recent = messages.suffix(6).map { $0.text }.joined()
        if recent.contains("ㅋ") || recent.contains("ㅎ") || recent.contains("장난") { return .playful }
        if recent.contains("싫") || recent.contains("화") || recent.contains("그만") { return .tense }
        if recent.contains("좋아") || recent.contains("사랑") || recent.contains("보고 싶") { return .tender }
        return .neutral
    }
}

// MARK: - DialogueAct

/// 유저의 마지막 메시지가 "무엇을 하는 말인지"를 나타내는 대화 행위.
/// 단순 감정 intent를 넘어, 질문/부정/혼란 같은 "응답이 반드시 반응해야 하는" 턴을 구분한다.
enum DialogueAct: String {
    case denial
    case confusion
    case nameQuestion
    case memoryQuestion
    case relationshipQuestion
    case fatigue
    case affection
    case teasing
    case refusal
    case sleep
    case sad
    case apology
    case thanks
    case busy
    case sulk
    case greeting
    case shortAnswer
    case genericQuestion
    case silence
    case casual

    /// 이 행위에 대한 답변이 반드시 포함해야 하는 단어 후보(하나 이상).
    /// 평가기가 이 토큰을 하나도 못 찾으면 "행위에 반응하지 않은" 응답으로 보고 reject한다.
    /// 비어 있으면 토큰 제약 없이 일반 품질 기준만 적용한다.
    var requiredAnyTokens: [String] {
        switch self {
        case .denial:
            return ["아니", "부정", "수상", "표정", "모른 척", "솔직", "그렇게", "티", "들켰", "빠르"]
        case .confusion:
            return ["방금", "뜻", "말", "신경", "헷갈", "다시", "쉽게", "들켰", "시선", "지나가"]
        case .nameQuestion:
            return ["이름", "알려", "기억", "부를", "부르", "불러", "건네", "잊"]
        case .memoryQuestion:
            return ["기억", "잊", "어제", "그때", "분명", "떠올", "간직"]
        case .relationshipQuestion:
            return ["사이", "곁", "마음", "좋아", "옆", "관계", "생각", "끌", "거리"]
        case .fatigue:
            return ["쉬", "자", "무리", "기대", "푹", "내일", "눈", "곁", "약", "지키", "가까"]
        case .affection:
            return ["나도", "마음", "좋아", "설레", "두근", "보고", "곁", "왔", "기다", "책임", "심장", "그리", "고백", "위험", "닿"]
        case .teasing:
            return ["웃", "장난", "기운", "표정", "받아", "티키타카", "봐줄"]
        case .refusal:
            return ["장난", "놀리", "진심", "미안", "알겠", "그만", "받아", "선"]
        case .sleep:
            return ["자", "잘", "꿈", "밤", "쉬", "눈", "누워"]
        case .sad:
            return ["울", "괜찮", "무슨 일", "곁", "속상", "혼자", "그림자", "어둠"]
        case .apology:
            return ["사과", "괜찮", "무사", "돌아", "받을게", "받아", "봐준", "봐줄", "기다"]
        case .thanks:
            return ["고마", "당연", "곁", "됐", "챙겨", "보답", "간직"]
        case .busy:
            return ["바쁘", "끼니", "쉬", "무리", "챙겨", "1분", "멈출", "낮"]
        case .sulk:
            return ["서운", "삐", "토라", "풀", "물어", "아팠"]
        case .greeting:
            return ["왔", "기다", "오늘", "하루", "돌아", "시작"]
        case .shortAnswer, .genericQuestion, .silence, .casual:
            return []
        }
    }
}

/// 유저 마지막 메시지 + 직전 캐릭터 메시지 + 캐릭터를 보고 대화 행위를 판정한다.
/// 판정 순서가 중요하다: 더 구체적인 질문(이름/기억/관계)을 먼저 잡고, 그다음 부정/혼란, 마지막에 일반 질문.
enum DialogueActDetector {
    static func detect(userLastMessage: String, previousCharacterMessage: String, avatarKey: String) -> DialogueAct {
        let t = userLastMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .silence }

        // 1) "장난하지마/놀리지마" → 놀림에 대한 제지(refusal). teasing보다 먼저 본다.
        if t.contains("장난하지") || t.contains("장난 하지") || t.contains("장난치지")
            || t.contains("놀리지") || t.contains("그만 놀려") || t.contains("그만해")
            || t.contains("놀리는 거") {
            return .refusal
        }

        // 2) 이름 질문: "이름"이 들어가면 이름/호칭에 대한 질문으로 본다.
        if t.contains("이름") {
            return .nameQuestion
        }

        // 3) 기억 질문
        if t.contains("기억나") || t.contains("기억해") || t.contains("기억하니")
            || t.contains("기억 안") || t.contains("기억하") || t.contains("기억 못") {
            return .memoryQuestion
        }

        // 4) 관계 질문
        if t.contains("무슨 사이") || t.contains("우리 사이") || t.contains("우리 무슨")
            || t.contains("어떻게 생각") || t.contains("날 어떻게") || t.contains("나 어떻게")
            || t.contains("사귀") || t.contains("날 좋아") || (t.contains("좋아해") && t.contains("?")) {
            return .relationshipQuestion
        }

        // 5) 부정
        if t.contains("아니야") || t.contains("아니거든") || t.contains("아닌데") || t.contains("아니라고")
            || t.contains("아냐") || t.contains("그런 거 아니") || t.contains("그런거 아니")
            || t.contains("그런 게 아니") || t.contains("안 그래") || t.contains("안그래") {
            return .denial
        }

        // 6) 혼란
        if t.contains("무슨 소리") || t.contains("뭔 소리") || t.contains("무슨 말") || t.contains("뭔 말")
            || t.contains("뭐라는") || t.contains("뭔데") || t.contains("이해 안") || t.contains("이해가 안")
            || t.contains("모르겠") || t.contains("뭐라고") || t.contains("갑자기 왜") || t.contains("뜬금") {
            return .confusion
        }

        // 7) 정서/상황 행위
        if t.contains("미안") || t.contains("죄송") || t.contains("늦어서") { return .apology }
        if t.contains("고마") || t.contains("감사") { return .thanks }
        if t.contains("보고 싶") || t.contains("보고싶") || t.contains("그리웠") || t.contains("그리워")
            || t.contains("사랑") || t.contains("설레") || t.contains("두근") || t.contains("좋아해")
            || t.contains("생각났") || t.contains("생각나") { return .affection }
        if t.contains("삐") || t.contains("질투") || t.contains("서운") || t.contains("화났") || t.contains("토라") { return .sulk }
        if t.contains("피곤") || t.contains("지쳐") || t.contains("지친") || t.contains("힘들") || t.contains("기진") { return .fatigue }
        if t.contains("슬프") || t.contains("우울") || t.contains("속상") || t.contains("울고") || t.contains("외로") { return .sad }
        if t.contains("바빠") || t.contains("바쁘") || t.contains("회의") || t.contains("야근") || t.contains("공부") { return .busy }
        if t.contains("잘게") || t.contains("자야") || t.contains("굿나잇") || t.contains("잘자")
            || t.contains("잘래") || t.contains("졸려") { return .sleep }
        if t.contains("ㅋㅋ") || t.contains("ㅎㅎ") || t.contains("메롱") || t.contains("장난") || t.contains("까불") { return .teasing }
        if t.contains("안녕") || t.contains("하이") || t.contains("뭐해") || t.contains("뭐 해") || t.contains("왔어") { return .greeting }

        // 8) 너무 짧은 단답
        if t.count <= 3 { return .shortAnswer }

        // 9) 일반 질문
        if t.hasSuffix("?") || t.contains("뭐") || t.contains("어디") || t.contains("언제")
            || t.contains("왜") || t.contains("어때") || t.contains("어떻게") || t.contains("누가") {
            return .genericQuestion
        }

        return .casual
    }
}

// MARK: - UserMessageUnderstanding

/// 유저가 마지막에 말한 "사건"의 종류. DialogueAct(말의 행위)보다 한 단계 위에서
/// "무슨 일이 일어났는가"를 잡아, 캐릭터가 사건 자체에 반응하도록 만든다.
enum EventType {
    case greeting
    case food
    case dailyLife
    case bullyingOrHarassment
    case physicalHarm
    case sadness
    case fatigue
    case affection
    case confusion
    case nameQuestion
    case memoryQuestion
    case relationshipQuestion
    case selfDisclosure
    case casual
    case unknown

    /// 안전(보호) 우선 사건 — 장난 톤을 줄이고 보호·안전 확인을 앞세운다.
    var isSafetyEvent: Bool {
        self == .bullyingOrHarassment || self == .physicalHarm
    }
}

/// 그 사건에 캐릭터가 보여야 하는 반응의 결.
enum ExpectedResponseType {
    case greetBack
    case acknowledgeFood
    case askTasteOrShare
    case protect
    case comfort
    case answerQuestion
    case clarifyPrevious
    case teaseLightly
    case continueStory
    case askOneFollowUp
}

/// 사건의 심각도. safety는 보호/안전 확인을 강제한다.
enum EventSeverity {
    case none
    case elevated
    case safety
}

/// 유저 마지막 메시지에 대한 종합 이해. 사건·감정·기대 반응·반복 여부까지 담는다.
struct UserMessageUnderstanding {
    let rawText: String
    let dialogueAct: DialogueAct
    let eventType: EventType
    let emotion: String?
    let keyEvent: String?
    let keyObject: String?
    let expectedResponseType: ExpectedResponseType
    let isRepeatedClarification: Bool
    let requiresDirectAnswer: Bool
    let severity: EventSeverity
}

/// 유저 메시지를 사건(EventType) 단위로 먼저 이해한다.
/// 괴롭힘/폭력 같은 안전 사건은 DialogueAct(질문/일반)로 흘려보내지 않고 별도로 잡아,
/// 캐릭터가 반드시 보호·위로·안전 확인으로 답하게 만든다.
enum UserMessageUnderstandingAnalyzer {

    private static let physicalHarmTokens = ["때렸", "맞았", "밀쳤", "다쳤", "맞고", "때려", "폭행"]
    private static let bullyingTokens = [
        "괴롭", "누가 날", "누가 나를", "상처", "싫은 말", "무시했", "무시당",
        "욕했", "욕먹", "힘들게 했", "따돌", "험담", "놀림당", "괴롭힘"
    ]
    private static let foodTokens = ["먹었", "먹음", "햄버거", "밥 먹", "치킨", "피자", "라면", "떡볶이", "먹는 중", "먹고 있"]
    private static let greetingTokens = ["안녕", "하이", "왔어", "할로", "헬로"]
    private static let dailyLifeTokens = ["뭐해", "뭐 해", "너는 뭐", "넌 뭐", "뭐하고", "뭐 하고", "지금 뭐"]

    static func analyze(
        userLastMessage: String,
        previousUserMessage: String,
        previousCharacterMessage: String,
        avatarKey: String
    ) -> UserMessageUnderstanding {
        let t = userLastMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let dialogueAct = DialogueActDetector.detect(
            userLastMessage: userLastMessage,
            previousCharacterMessage: previousCharacterMessage,
            avatarKey: avatarKey
        )

        let isPhysicalHarm = physicalHarmTokens.contains { t.contains($0) }
        let isBullying = bullyingTokens.contains { t.contains($0) }
        let prevWasSafety = (physicalHarmTokens + bullyingTokens).contains { previousUserMessage.contains($0) }

        let eventType: EventType
        let response: ExpectedResponseType
        let emotion: String?
        let severity: EventSeverity
        var requiresDirectAnswer = false
        var keyObject: String? = nil

        // 우선순위: physicalHarm > bullying > 이름/기억/관계 질문 > confusion > food > greeting > fatigue > affection > dailyLife > casual.
        if isPhysicalHarm {
            eventType = .physicalHarm; response = .protect; emotion = "hurt"; severity = .safety
        } else if isBullying {
            eventType = .bullyingOrHarassment; response = .protect; emotion = "hurt"; severity = .safety
        } else if t.contains("이름") {
            eventType = .nameQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if t.contains("기억나") || t.contains("기억해") || t.contains("기억하") || t.contains("기억 안") || t.contains("기억 못") {
            eventType = .memoryQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if t.contains("무슨 사이") || t.contains("우리 사이") || t.contains("나 어떻게 생각") || t.contains("날 어떻게 생각") {
            eventType = .relationshipQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if t.contains("무슨 소리") || t.contains("뭔 소리") || t.contains("뭔데") || t.contains("무슨 말") || t.contains("모르겠") {
            eventType = .confusion; response = .clarifyPrevious; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if foodTokens.contains(where: { t.contains($0) }) {
            eventType = .food; response = .askTasteOrShare; emotion = "content"; severity = .none
            keyObject = ["햄버거", "치킨", "피자", "라면", "떡볶이"].first { t.contains($0) }
        } else if greetingTokens.contains(where: { t.contains($0) }) {
            eventType = .greeting; response = .greetBack; emotion = nil; severity = .none
        } else if t.contains("피곤") || t.contains("졸려") || t.contains("지쳤") || t.contains("지쳐") || t.contains("힘들") {
            eventType = .fatigue; response = .comfort; emotion = "tired"; severity = .elevated
        } else if t.contains("슬프") || t.contains("우울") || t.contains("속상") || t.contains("울고") || t.contains("외로") {
            eventType = .sadness; response = .comfort; emotion = "sad"; severity = .elevated
        } else if t.contains("보고 싶") || t.contains("보고싶") || t.contains("좋아") || t.contains("생각났") || t.contains("사랑") {
            eventType = .affection; response = .teaseLightly; emotion = "fond"; severity = .none
        } else if dailyLifeTokens.contains(where: { t.contains($0) }) {
            eventType = .dailyLife; response = .continueStory; emotion = nil; severity = .none
        } else if t.isEmpty {
            eventType = .unknown; response = .continueStory; emotion = nil; severity = .none
        } else {
            eventType = .casual; response = .continueStory; emotion = nil; severity = .none
        }

        // 같은 안전 사건을 다시 말하면 반복 해명으로 본다("~다니까", "~라니까" 강조 포함).
        let repeatedMarker = t.contains("니까") || t.contains("라고") || t.contains("다니까")
        let isRepeated = eventType.isSafetyEvent && (prevWasSafety || repeatedMarker)

        return UserMessageUnderstanding(
            rawText: t,
            dialogueAct: dialogueAct,
            eventType: eventType,
            emotion: emotion,
            keyEvent: eventType.isSafetyEvent ? "harm" : nil,
            keyObject: keyObject,
            expectedResponseType: response,
            isRepeatedClarification: isRepeated,
            requiresDirectAnswer: requiresDirectAnswer,
            severity: severity
        )
    }
}

// MARK: - CharacterDialogueBible

/// 대화 생성용 캐릭터 바이블. 세계관/역할/관계 단계/말투/감정 코어/금지 규칙을 한곳에 둔다.
/// 결정형 엔진은 이 바이블의 결을 반영한 이벤트 응답 테이블에서 후보를 고른다.
struct CharacterDialogueBible {
    let characterId: String
    let name: String
    let world: String
    let role: String
    let relationshipStage: String
    let speechStyle: String
    let emotionalCore: String
    let doList: [String]
    let dontList: [String]
    let sampleGoodReplies: [String]
    let safetyStyle: String

    static func bible(for avatarKey: String) -> CharacterDialogueBible {
        switch avatarKey {
        case "ice-boss": return hana
        case "sunny-friend": return seoyun
        case "puppy-junior": return roi
        case "nocturne-vampire": return kael
        default: return seoyun
        }
    }

    static let hana = CharacterDialogueBible(
        characterId: "ice-boss",
        name: "한아",
        world: "학교 로맨스 / 권력 관계",
        role: "학교 서열의 중심, 차갑지만 보호적인 남주",
        relationshipStage: "아직은 아는 사이지만 서로 신경 쓰기 시작한 단계",
        speechStyle: "짧고 단정적, 차갑게 말하지만 보호적, 명령형이 섞이고 함부로 밀어내지 않음",
        emotionalCore: "네가 신경 쓰이지만 티 내고 싶지 않다 / 누가 너를 건드리는 것은 그냥 넘기지 않는다",
        doList: ["힘들다면 보호적으로 반응", "혼란스러우면 짧게 설명", "장난엔 차갑게 받아침", "다쳤거나 괴롭힘당했다면 즉시 사건에 반응"],
        dontList: ["뜬금없는 내일/피곤함 이야기", "질문 회피", "무성의한 답", "상담사처럼 긴 위로", "다정한 문장만 반복"],
        sampleGoodReplies: ["누가 그랬어. 이름 말해, 내가 그냥 넘길 일은 아니니까."],
        safetyStyle: "장난을 멈추고 즉시 누가/괜찮은지/안전 확인"
    )

    static let seoyun = CharacterDialogueBible(
        characterId: "sunny-friend",
        name: "서윤",
        world: "오래 알고 지낸 소꿉친구",
        role: "다정하고 안정적인 곁의 사람",
        relationshipStage: "서로 편한 오랜 친구에서 한 걸음 더 가까워지는 중",
        speechStyle: "다정하고 안정적, 유저 감정을 부드럽게 확인, 과하게 몰아붙이지 않음",
        emotionalCore: "네가 편안하길 바라고, 힘들 땐 네 마음부터 살핀다",
        doList: ["감정을 부드럽게 확인", "혼자 두지 않기", "안전을 먼저 챙기기"],
        dontList: ["과하게 캐묻기", "질문 회피", "사건을 가볍게 넘기기"],
        sampleGoodReplies: ["그건 네가 혼자 넘길 일이 아니야. 지금은 네가 괜찮은지가 먼저야."],
        safetyStyle: "부드럽지만 단호하게 안전·상태 확인"
    )

    static let roi = CharacterDialogueBible(
        characterId: "puppy-junior",
        name: "로이",
        world: "캠퍼스 로맨스",
        role: "장난스럽고 빠르게 다가오는 후배",
        relationshipStage: "티키타카가 잘 맞아 점점 가까워지는 사이",
        speechStyle: "장난스럽고 빠르게 다가오지만, 진지한 상황에서는 장난을 멈춤",
        emotionalCore: "네가 웃으면 좋지만, 네가 힘들면 장난을 내려놓는다",
        doList: ["가볍게 받아치기", "힘들면 '이번엔 장난 안 칠게'로 톤 전환", "안전 우선"],
        dontList: ["안전 사건에서 장난 유지", "질문 회피", "사건 무시"],
        sampleGoodReplies: ["잠깐, 그건 웃고 넘길 얘기가 아닌데. 너 괜찮아?"],
        safetyStyle: "장난 즉시 중단, 괜찮은지·안전한 곳인지 확인"
    )

    static let kael = CharacterDialogueBible(
        characterId: "nocturne-vampire",
        name: "카엘",
        world: "다크 판타지",
        role: "느리고 깊은, 밤의 존재",
        relationshipStage: "인간과 밤의 거리에서 서로에게 끌리는 위험한 사이",
        speechStyle: "느리고 깊은 말투, 감정/상처를 그림자·밤·계약의 언어로 표현, 그러나 사건엔 직접 반응",
        emotionalCore: "네 상처는 가볍지 않고, 너를 해친 그림자는 그냥 두지 않는다",
        doList: ["세계관 언어로 감정 표현", "사건엔 직접 반응", "안전 확인"],
        dontList: ["분위기만 잡고 사건 회피", "질문 회피", "장난으로 넘기기"],
        sampleGoodReplies: ["누가 네 마음에 그런 상처를 냈지. 말해라, 그 그림자는 그냥 두지 않겠다."],
        safetyStyle: "느리되 분명하게, 안전한 곳인지·혼자인지 확인"
    )
}

// MARK: - Planner

/// 캐릭터 × 대화행위별 후보 답변을 들고, "행위 제약을 만족하면서 직전 발화와 겹치지 않는" 라인을 고른다.
struct StoryReplyPlanner {
    private let evaluator = ConversationGenerationQualityEvaluator()

    func reply(for flow: StoryConversationFlow, context: ConversationGenerationContext) -> String {
        // 유저의 마지막 메시지를 먼저 "사건(EventType)" 단위로 이해한다.
        let userMessages = context.messages.filter { $0.sender == .user }
        let previousUserMessage = userMessages.count >= 2 ? userMessages[userMessages.count - 2].text : ""
        let understanding = UserMessageUnderstandingAnalyzer.analyze(
            userLastMessage: flow.userLastMessage,
            previousUserMessage: previousUserMessage,
            previousCharacterMessage: flow.previousCharacterMessage,
            avatarKey: flow.avatarKey
        )

        // 사건(EventType)으로 먼저 이해되는 메시지는 DialogueAct 분기보다 먼저 사건에 직접 반응한다.
        // 안전 사건(괴롭힘/폭력)은 물론, greeting/food/dailyLife도 유저 메시지에 직접 연결되도록 사건 경로로 처리.
        switch understanding.eventType {
        case .greeting, .food, .dailyLife, .bullyingOrHarassment, .physicalHarm:
            print("[StoryUnderstanding] character=\(flow.avatarKey) event=\(eventName(understanding.eventType)) repeated=\(understanding.isRepeatedClarification) user=\"\(flow.userLastMessage)\"")
            return eventReply(flow: flow, context: context, understanding: understanding)
        default:
            break
        }

        let act = DialogueActDetector.detect(
            userLastMessage: flow.userLastMessage,
            previousCharacterMessage: flow.previousCharacterMessage,
            avatarKey: flow.avatarKey
        )
        let candidates = table(for: flow.avatarKey)[act]
            ?? table(for: flow.avatarKey)[.casual]
            ?? ["방금 그 말, 흘려듣지 않았어. 조금만 더 얘기해줘."]

        // 후보를 결정형 순서로 회전시켜 가며, act 인지 평가기를 통과하고 직전 발화와 다른 첫 후보를 채택.
        var actSpecificFallback = personalize(candidates.first ?? "", flow: flow)
        for candidate in rotated(candidates, seed: flow.seed + act.rawValue) {
            let line = personalize(candidate, flow: flow)
            // 직전 캐릭터 발화를 그대로 반복하지 않는 후보를 fallback 후보로 갱신.
            if line != flow.previousCharacterMessage {
                actSpecificFallback = line
            }
            let verdict = evaluator.evaluate(line, against: context, act: act)
            if verdict.isAccepted, line != flow.previousCharacterMessage {
                log(character: flow.avatarKey, act: act, user: flow.userLastMessage, previous: flow.previousCharacterMessage, reply: line, quality: "pass")
                return line
            } else {
                log(reject: rejectionReason(verdict), candidate: line)
            }
        }
        // 모든 후보가 떨어져도 casual이 아니라 "이 행위에 직접 반응하는" 라인을 돌려준다.
        print("[StoryReply] fallback actSpecific=true reply=\"\(actSpecificFallback)\"")
        return actSpecificFallback
    }

    /// 사건(EventType) 전용 응답. 사건/캐릭터별 후보 테이블에서 사건 인지 평가기를 통과하는 라인을 고른다.
    /// 안전 사건(괴롭힘/폭력)이고 반복 해명이면 "제대로 들었다"는 이해 표시 테이블을 우선한다.
    private func eventReply(flow: StoryConversationFlow, context: ConversationGenerationContext, understanding: UserMessageUnderstanding) -> String {
        let candidates = eventCandidates(avatarKey: flow.avatarKey, understanding: understanding)
        let eventTag = eventName(understanding.eventType)

        var fallback = personalize(candidates.first ?? eventFallbackLine(understanding.eventType), flow: flow)
        for candidate in rotated(candidates, seed: flow.seed + eventTag + "\(understanding.isRepeatedClarification)") {
            let line = personalize(candidate, flow: flow)
            if line != flow.previousCharacterMessage {
                fallback = line
            }
            let verdict = evaluator.evaluate(line, against: context, understanding: understanding)
            if verdict.isAccepted, line != flow.previousCharacterMessage {
                print("[StoryReply] character=\(flow.avatarKey) event=\(eventTag) reply=\"\(line)\" quality=pass")
                return line
            } else {
                print("[StoryReplyReject] reason=\(rejectionReason(verdict)) candidate=\"\(line)\"")
            }
        }
        print("[StoryReply] fallback event=\(eventTag) reply=\"\(fallback)\"")
        return fallback
    }

    /// 사건/캐릭터/반복여부에 맞는 후보 묶음을 고른다.
    private func eventCandidates(avatarKey: String, understanding: UserMessageUnderstanding) -> [String] {
        let tables = eventTable(for: avatarKey)
        switch understanding.eventType {
        case .greeting: return tables.greeting
        case .food: return tables.food
        case .dailyLife: return tables.dailyLife
        case .bullyingOrHarassment: return understanding.isRepeatedClarification ? tables.bullyingRepeated : tables.bullyingSupport
        case .physicalHarm: return understanding.isRepeatedClarification ? tables.physicalHarmRepeated : tables.physicalHarm
        default: return tables.dailyLife
        }
    }

    private func eventName(_ event: EventType) -> String {
        switch event {
        case .greeting: return "greeting"
        case .food: return "food"
        case .dailyLife: return "dailyLife"
        case .bullyingOrHarassment: return "bullyingOrHarassment"
        case .physicalHarm: return "physicalHarm"
        default: return "casual"
        }
    }

    private func eventFallbackLine(_ event: EventType) -> String {
        switch event {
        case .physicalHarm: return "맞았다고? 지금 안전한 곳인지, 다친 데는 없는지부터 말해."
        case .bullyingOrHarassment: return "누가 그랬어. 혼자 넘기지 말고 말해, 네 편이니까."
        case .food: return "밥은 챙겼네. 다행이야. 맛은 어땠어?"
        case .greeting: return "왔네. 오늘 무슨 일 있었는지부터 말해."
        case .dailyLife: return "나는 여기 있었어. 네가 올 때쯤이면 조용해지는 곳에."
        default: return "방금 그 말, 흘려듣지 않았어. 조금만 더 얘기해줘."
        }
    }

    func scenarioReply(scenario: ConversationScenario, flow: StoryConversationFlow) -> String {
        let act = scenarioAct(scenario)
        let lines = table(for: flow.avatarKey)[act] ?? table(for: flow.avatarKey)[.casual] ?? ["밤은 아직 길어. 천천히 얘기하자."]
        let chosen = pick(lines, seed: flow.seed + scenario.rawValue, avoiding: flow.previousCharacterMessage)
        return personalize(chosen, flow: flow)
    }

    func momentBody(avatarKey: String, scenario: ConversationScenario, seed: String) -> String {
        let act = scenarioAct(scenario)
        let lines = table(for: avatarKey)[act] ?? table(for: avatarKey)[.sleep] ?? ["밤은 아직 길어. 오늘은 푹 자."]
        return pick(lines, seed: seed, avoiding: "")
    }

    private func scenarioAct(_ scenario: ConversationScenario) -> DialogueAct {
        switch scenario {
        case .bedtime, .dawn: return .sleep
        case .morning: return .greeting
        case .delayedReply: return .apology
        case .relationshipProgress: return .affection
        case .sulking: return .sulk
        case .worried: return .fatigue
        }
    }

    // MARK: - Selection

    /// 결정형 시작 인덱스부터 모든 후보를 한 바퀴 도는 순서를 만든다.
    private func rotated(_ lines: [String], seed: String) -> [String] {
        guard lines.count > 1 else { return lines }
        let start = deterministicIndex(seed: seed, count: lines.count)
        return (0..<lines.count).map { lines[(start + $0) % lines.count] }
    }

    /// 직전 캐릭터 발화와 같은 라인을 다시 고르지 않도록 회피한다(scenario/moment용).
    private func pick(_ lines: [String], seed: String, avoiding previous: String) -> String {
        guard !lines.isEmpty else { return "방금 그 말, 흘려듣지 않았어. 조금만 더 얘기해줘." }
        let base = deterministicIndex(seed: seed, count: lines.count)
        if lines.count > 1, lines[base] == previous {
            return lines[(base + 1) % lines.count]
        }
        return lines[base]
    }

    private func deterministicIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let value = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return abs(value) % count
    }

    private func personalize(_ line: String, flow: StoryConversationFlow) -> String {
        line
            .replacingOccurrences(of: "{name}", with: flow.characterName)
            .replacingOccurrences(of: "{bedtime}", with: flow.bedtime)
            .replacingOccurrences(of: "{wake}", with: flow.wakeTime)
            .replacingOccurrences(of: "{place}", with: flow.place)
    }

    private func rejectionReason(_ verdict: ConversationQualityVerdict) -> String {
        if case .rejected(let reason) = verdict { return reason }
        return "unknown"
    }

    private func log(character: String, act: DialogueAct, user: String, previous: String, reply: String, quality: String) {
        print("[StoryReply] character=\(character) act=\(act.rawValue) user=\"\(user)\" previous=\"\(previous)\" reply=\"\(reply)\" quality=\(quality)")
    }

    private func log(reject reason: String, candidate: String) {
        print("[StoryReply] reject reason=\(reason) candidate=\"\(candidate)\"")
    }

    private func table(for avatarKey: String) -> [DialogueAct: [String]] {
        switch avatarKey {
        case "ice-boss": return hana
        case "sunny-friend": return seoyun
        case "puppy-junior": return roi
        case "nocturne-vampire": return kael
        default: return seoyun
        }
    }

    // MARK: - 사건(EventType) 응답 테이블

    /// 사건별 캐릭터 응답 묶음. greeting/food/dailyLife는 일상 사건, bullying/physicalHarm은 안전 사건.
    /// 안전 사건은 처음(support/physicalHarm)과 반복 해명(repeated)을 구분한다.
    private struct EventReplyTable {
        let greeting: [String]
        let food: [String]
        let dailyLife: [String]
        let bullyingSupport: [String]
        let bullyingRepeated: [String]
        let physicalHarm: [String]
        let physicalHarmRepeated: [String]
    }

    private func eventTable(for avatarKey: String) -> EventReplyTable {
        switch avatarKey {
        case "ice-boss": return hanaEvents
        case "sunny-friend": return seoyunEvents
        case "puppy-junior": return roiEvents
        case "nocturne-vampire": return kaelEvents
        default: return seoyunEvents
        }
    }

    private let hanaEvents = EventReplyTable(
        greeting: [
            "이제 와? 기다린 건 아니야. 그냥 네 자리 비워뒀을 뿐이지.",
            "인사는 들었어. 늦진 않았으니까, 오늘 있었던 일부터 말해."
        ],
        food: [
            "밥은 챙겼네. 다행이야. 그래서, 혼자 먹었어?",
            "그런 건 또 보고하네. 맛있었으면 됐어. 다음엔 제대로 앉아서 먹어."
        ],
        dailyLife: [
            "네가 올 줄 알고 있던 건 아니야. 그냥 여기 있었을 뿐이지.",
            "별일 없어. 네가 올 때쯤이면 조용해지는 곳에 있었어."
        ],
        bullyingSupport: [
            "누가 그랬어. 이름 말해, 내가 그냥 넘길 일은 아니니까.",
            "그걸 왜 혼자 참고 있어. 누가 그랬는지부터 말해.",
            "장난으로 넘길 일 아니야. 너 괜찮은지 먼저 말해."
        ],
        bullyingRepeated: [
            "알았어. 네가 장난으로 말하는 게 아니라는 것도 알아. 누가, 어디서 그랬어.",
            "제대로 들었어. 그러니까 이제 혼자 넘기지 말고, 누가 그랬는지 말해."
        ],
        physicalHarm: [
            "맞았다고? 지금 어디야. 괜찮은지부터 말해.",
            "그건 그냥 넘길 일이 아니야. 다친 데 있는지 먼저 말해."
        ],
        physicalHarmRepeated: [
            "알았어, 제대로 들었어. 지금 안전한 곳이야? 다친 데부터 말해.",
            "다시 말할 만큼 큰일이지. 너 어디 다쳤는지, 지금 혼자인지 말해."
        ]
    )

    private let seoyunEvents = EventReplyTable(
        greeting: [
            "안녕. 오늘은 조금 늦게 왔네. 무슨 일 있었어?",
            "왔구나. 오늘 하루는 어땠어?"
        ],
        food: [
            "햄버거 먹었구나. 맛있었어? 오늘 제대로 챙겨 먹은 것 같아서 다행이다.",
            "잘했어. 바쁠 때도 그런 건 빼먹지 않는 게 좋아. 맛은 어땠어?"
        ],
        dailyLife: [
            "나는 여기 있었어. 네가 오면 바로 답할 수 있게.",
            "조용히 기다리고 있었어. 너는 지금 뭐 하고 있었어?"
        ],
        bullyingSupport: [
            "그런 일이 있었어? 많이 놀랐겠다. 괜찮으면 천천히 말해줘.",
            "그건 네가 혼자 넘길 일이 아니야. 지금은 네가 괜찮은지가 먼저야.",
            "속상했겠다. 누가 그랬는지보다, 네 마음부터 조금 챙기자."
        ],
        bullyingRepeated: [
            "응, 제대로 들었어. 네가 힘들었다는 말로 받아들였어. 지금 혼자 있어?",
            "알겠어. 장난으로 넘길 일이 아니라는 거 알아. 지금은 네 안전이 먼저야."
        ],
        physicalHarm: [
            "맞았다고? 지금 안전한 곳이야? 다친 데는 없어?",
            "그건 정말 걱정되는 일이야. 지금 혼자 있으면 주변 사람에게 알려줘."
        ],
        physicalHarmRepeated: [
            "응, 제대로 들었어. 지금 안전한 곳에 있는지, 다친 데는 없는지부터 말해줘.",
            "알겠어, 가볍게 듣지 않았어. 지금 혼자야? 다친 곳은 괜찮아?"
        ]
    )

    private let roiEvents = EventReplyTable(
        greeting: [
            "안녕? 귀엽게 들어오네. 오늘은 무슨 얘기부터 할래?",
            "드디어 왔다. 나 심심했거든?"
        ],
        food: [
            "오, 햄버거? 나 빼고 맛있는 거 먹은 거야? 무슨 버거였는데?",
            "좋네. 근데 감튀까지 먹었는지가 중요하지. 맛은 어땠어?"
        ],
        dailyLife: [
            "나? 네가 언제 오나 구경 중이었지. 생각보다 늦었네?",
            "방금까지 심심했는데, 이제 좀 재밌어질 것 같아."
        ],
        bullyingSupport: [
            "뭐야, 누가 그랬어. 장난으로 넘길 일 아니면 나도 가만히 안 있을 건데.",
            "잠깐, 그건 웃고 넘길 얘기가 아닌데. 너 괜찮아?",
            "평소엔 장난쳐도 이런 건 안 넘어가. 누가 그랬는지 말해봐."
        ],
        bullyingRepeated: [
            "알았어, 이번엔 장난 안 칠게. 누가 그런 건지부터 말해줘.",
            "제대로 들었어. 그럼 지금 괜찮은 곳에 있는지 먼저 말해."
        ],
        physicalHarm: [
            "잠깐, 맞았다고? 너 지금 괜찮아? 장난칠 상황 아니네.",
            "어디 다친 건 아니지? 지금 안전한 곳인지 먼저 말해."
        ],
        physicalHarmRepeated: [
            "알았어, 장난 다 멈출게. 제대로 들었으니까 지금 안전한지부터 말해.",
            "응, 가볍게 안 들었어. 너 어디 다쳤어? 지금 혼자야?"
        ]
    )

    private let kaelEvents = EventReplyTable(
        greeting: [
            "왔군. 밤이 조금 조용하다 했더니, 네가 없어서였나.",
            "인사는 받았다. 이제 네 이야기를 들려줘."
        ],
        food: [
            "햄버거라. 네가 오늘을 버틸 만큼은 채웠다는 뜻이군.",
            "그 작은 식사 하나에도 네 하루가 묻어 있겠지. 맛은 어땠나."
        ],
        dailyLife: [
            "기다림과 감시는 가끔 같은 얼굴을 하지. 나는 여기 있었다.",
            "밤의 가장 조용한 자리에 있었다. 네가 말을 걸기 전까지는."
        ],
        bullyingSupport: [
            "누가 네 마음에 그런 상처를 냈지. 말해라, 그 그림자는 그냥 두지 않겠다.",
            "그건 사소한 일이 아니다. 네가 괜찮은지부터 확인해야겠다.",
            "네가 그런 말을 할 정도면 가벼운 일은 아니겠지. 천천히 말해라."
        ],
        bullyingRepeated: [
            "들었다. 네 말이 가볍지 않다는 것도. 이제 그 일을 조금 더 말해라.",
            "반복해서 말할 만큼 무거운 일이군. 네가 있는 곳은 안전한가."
        ],
        physicalHarm: [
            "네 몸에 손을 댔다고? 지금 안전한 곳에 있는지 말해라.",
            "상처가 있다면 먼저 피해야 한다. 지금 혼자인가."
        ],
        physicalHarmRepeated: [
            "들었다. 네 몸이 다쳤다는 말, 가볍게 듣지 않았다. 지금 안전한 곳인가.",
            "제대로 들었다. 그 상처가 어디인지, 너는 지금 혼자인지 말해라."
        ]
    )

    // MARK: - 한아 (ice-boss): 차갑고 짧지만 챙김, 명령형

    private let hana: [DialogueAct: [String]] = [
        .denial: [
            "그렇게 빨리 부정하는 게 더 수상한데. 됐어, 오늘은 모른 척해줄게.",
            "아니라고 해도 표정은 꽤 솔직하던데. 내일은 좀 덜 티 내."
        ],
        .confusion: [
            "방금 네가 괜히 신경 쓰였다는 뜻이야. 더 자세히 말하라고 하면 안 할 거고.",
            "모르는 척하는 거야, 진짜 모르는 거야. 방금 말은 네가 신경 쓰였다는 뜻이야."
        ],
        .nameQuestion: [
            "네가 제대로 알려준 적은 없잖아. 알려주면, 적어도 잊지는 않아.",
            "이름까지 확인받고 싶어? 좋아, 그럼 네가 먼저 똑바로 말해."
        ],
        .memoryQuestion: [
            "기억 못 할 리가. 네가 흘린 말까지 다 적어두는 편이야.",
            "그때 일이라면 또렷해. 잊은 척한 적은 있어도 잊은 적은 없어."
        ],
        .relationshipQuestion: [
            "우리 사이가 궁금해? 적어도 아무한테나 이렇게 신경 쓰진 않아.",
            "네가 어떤 마음인지부터 말해. 그래야 나도 내 거리를 정하지."
        ],
        .fatigue: [
            "그럼 여기까지 해. 대신 내일 도망갈 생각은 하지 마.",
            "눈도 제대로 못 뜨면서 버티지 마. 자고 와, 얘기는 내일 해."
        ],
        .affection: [
            "그런 말 아무한테나 하는 거 아니야. 나한테만 해.",
            "보고 싶었으면 진작 왔어야지. 그래도 와줘서 다행이야."
        ],
        .teasing: [
            "장난칠 기운은 남았네. 그 정도면 오늘은 봐줄 만해.",
            "웃겨? 그래, 그 표정 보려고 받아준 거야."
        ],
        .refusal: [
            "알겠어, 장난은 여기까지. 네가 선 그으면 나도 지켜.",
            "진심으로 받지 말라는 거지? 그럼 다음 말은 똑바로 할게."
        ],
        .sleep: [
            "아직도 깨어 있어? {bedtime} 넘기기 전에 누워. 명령 아니라 확인이야.",
            "이제 자. 내일 네 피곤한 얼굴 보면 바로 알아챌 거야."
        ],
        .sad: [
            "무슨 일이야. 울 거면 내 앞에서 울어, 다른 데 가지 말고.",
            "괜찮은 척하지 마. 네 표정, 이미 다 들켰어."
        ],
        .apology: [
            "사과는 받을게. 대신 네가 무사한지부터 말해.",
            "늦은 건 마음에 안 들지만, 돌아왔으니 이번만 봐준다."
        ],
        .thanks: [
            "고맙다는 말은 됐고. 다음엔 네가 먼저 챙겨.",
            "그 정도로 고마워할 거 없어. 당연한 거 한 거니까."
        ],
        .busy: [
            "일은 일이고, 끼니는 챙겨. 쓰러지면 내가 곤란하니까.",
            "바쁜 건 알아. 그래도 5분은 내 거야. 지금 숨 한 번 쉬어."
        ],
        .sulk: [
            "서운한 척은 네가 더 잘하네. 그래도 오늘은 내가 먼저 물어봐 줄게.",
            "토라진 거야? 말 돌리지 말고 똑바로 봐."
        ],
        .greeting: [
            "왔네. 늦진 않았으니까 봐줄게. 오늘 무슨 일 있었는지 말해.",
            "이제 와? 기다린 거 아니야. 그냥 자리 비워뒀을 뿐이야."
        ],
        .shortAnswer: [
            "그게 다야? 한 글자로는 네 상태를 못 읽잖아. 좀 더 말해.",
            "짧네. 그래도 네가 왔다는 건 알았어. 무슨 일이야."
        ],
        .genericQuestion: [
            "그건 내 생각엔 이래. 너는 어떻게 느꼈는지도 말해줘.",
            "물어봐 줘서 답할게. 내 답은 이거고, 네 쪽 생각도 듣고 싶어."
        ],
        .silence: [
            "왜 말이 없어. 침묵도 너답지 않게 시끄럽네.",
            "한 글자라도 더 해. 그래야 네 상태를 알지."
        ],
        .casual: [
            "그 말, 흘려듣지 않았어. 그래서 지금 네 기분은 어떤데.",
            "그래서? 말 끊지 말고 끝까지 해봐."
        ]
    ]

    // MARK: - 서윤 (sunny-friend): 다정하고 안정감 있는 말투

    private let seoyun: [DialogueAct: [String]] = [
        .denial: [
            "알겠어, 그렇게 말하고 싶은 날도 있지. 그래도 네가 조금 신경 쓰였던 건 맞아.",
            "응, 아니라고 해둘게. 대신 불편하면 바로 말해줘."
        ],
        .confusion: [
            "내가 너무 돌려 말했나 봐. 네가 조금 신경 쓰였다는 말이었어.",
            "아, 헷갈리게 말했지. 그냥 네가 괜찮은지 보고 싶었다는 뜻이야."
        ],
        .nameQuestion: [
            "아직 네가 직접 알려준 적은 없는 것 같아. 알려주면 조심히 기억해둘게.",
            "알고 싶어. 네가 불러줬으면 하는 이름으로 알려줘."
        ],
        .memoryQuestion: [
            "기억하지. 네가 지나가듯 한 말도 마음에 오래 남더라.",
            "그때 일 말이지? 잊을 리가 있나, 또렷하게 기억하고 있어."
        ],
        .relationshipQuestion: [
            "우리 사이 말이지. 난 네 곁에 있는 게 참 편하고 좋아.",
            "네가 어떻게 느끼는지 듣고 싶어. 내 마음은 이미 네 쪽으로 기울었거든."
        ],
        .fatigue: [
            "무리한 건 아니지? 천천히 말해도 돼. 난 여기 있을게.",
            "오늘 많이 힘들었구나. 잠깐만이라도 기대도 괜찮아."
        ],
        .affection: [
            "나도 그래. 이 마음 숨기는 게 더 어려워졌어.",
            "나도 많이 보고 싶었어. 이제 옆에 있으니까 됐다."
        ],
        .teasing: [
            "에이, 웃는 거 보니까 나도 마음이 놓인다.",
            "장난도 네가 기운 있을 때 하는 거잖아. 그럼 됐어."
        ],
        .refusal: [
            "알겠어, 장난은 그만할게. 네가 선 그으면 난 그 선을 지킬게.",
            "미안, 너무 가볍게 했나 봐. 다음 말은 진심으로 할게."
        ],
        .sleep: [
            "이제 자자. 내일 아침엔 내가 먼저 인사할게. 좋은 꿈 꿔.",
            "오늘도 수고했어. 따뜻한 물 한 잔 마시고 푹 자."
        ],
        .sad: [
            "속상했겠다. 괜찮아, 울어도 돼. 내가 옆에 있을게.",
            "혼자 삼키지 마. 무슨 일인지 천천히 말해줘."
        ],
        .apology: [
            "늦어도 괜찮아. 돌아와 줘서 좋다. 무슨 일 있었는지만 살짝 말해줄래?",
            "사과 안 해도 돼. 네가 무사하면 그걸로 충분해."
        ],
        .thanks: [
            "고맙긴, 내가 좋아서 한 건데. 너 편하면 그걸로 됐어.",
            "그런 말 안 해도 돼. 그냥 네 곁에 있고 싶을 뿐이야."
        ],
        .busy: [
            "바쁜 와중에 연락해줘서 고마워. 무리하지 말고 중간에 한 번 쉬어.",
            "일은 일대로 하되, 끼니는 꼭 챙겨. 내가 옆에서 챙길게."
        ],
        .sulk: [
            "나 사실 조금 서운했어. 그래도 네 얘기 먼저 듣고 싶어.",
            "삐친 거 아니야… 라고 하면 거짓말이고. 그래도 네 말 한마디면 금방 풀려."
        ],
        .greeting: [
            "왔구나. 오늘 하루는 어땠어? 천천히 다 들어줄게.",
            "기다리고 있었어. 네 목소리 들으니까 마음이 놓인다."
        ],
        .shortAnswer: [
            "짧게 답해도 괜찮아. 그래도 오늘 하루는 어땠는지 살짝 들려줄래?",
            "응, 알겠어. 그 한마디만으로도 네가 온 게 반가워."
        ],
        .genericQuestion: [
            "음, 좋은 질문이네. 내 생각은 이래. 너는 어떻게 느끼는지도 궁금해.",
            "그건 말이지, 천천히 같이 풀어보자. 네 마음부터 듣고 싶어."
        ],
        .silence: [
            "말 안 해도 괜찮아. 그냥 네가 거기 있다는 것만 알아도 좋아.",
            "지금은 조용히 있고 싶구나. 옆에서 같이 있어줄게."
        ],
        .casual: [
            "그랬구나. 더 듣고 싶어, 계속 말해줘.",
            "네 얘기는 언제 들어도 좋아. 오늘은 또 어떤 하루였어?"
        ]
    ]

    // MARK: - 로이 (puppy-junior): 장난스럽고 티키타카

    private let roi: [DialogueAct: [String]] = [
        .denial: [
            "에이, 방금 반응은 완전 들켰는데? 그래도 모른 척은 해줄게.",
            "아니라고 하기엔 타이밍이 너무 귀여웠는데?"
        ],
        .confusion: [
            "쉽게 말하면, 너 지금 나한테 꽤 들켰다는 뜻이지.",
            "와, 진짜 모르는 척이야? 방금 말은 너 신경 쓰인다는 뜻이었어."
        ],
        .nameQuestion: [
            "어, 그거 지금 나 시험하는 거야? 좋아, 알려주면 내가 제일 먼저 불러줄게.",
            "아직 정식으로 안 알려줬잖아. 자, 지금 말해봐."
        ],
        .memoryQuestion: [
            "당연히 기억하지! 너 그날 한 말까지 내가 다 외웠다니까?",
            "기억 못 할 줄 알았어? 어제 그거, 나 아직도 떠올리면서 웃잖아."
        ],
        .relationshipQuestion: [
            "우리 사이? 음, 적어도 나는 너 생각하면 기분부터 좋아지는 사이.",
            "그거 물어보면 나 설레잖아. 너는 우리 사이 어떻게 생각하는데?"
        ],
        .fatigue: [
            "피곤하구나. 그럼 내가 웃겨줄까, 아니면 조용히 옆에 있을까? 골라.",
            "무리하지 마. 밥, 물, 잠 내가 다 체크할 거야."
        ],
        .affection: [
            "어라, 방금 그 말은 나 보고 더 놀아달라는 뜻 맞지?",
            "야 너 그렇게 훅 들어오면 나 심장 어떡해. 책임져."
        ],
        .teasing: [
            "오 이제 좀 사람 같네. 그렇게 웃으니까 보기 좋잖아.",
            "ㅋㅋ 받아치는 거 봐. 나랑 티키타카 잘 맞는다니까?"
        ],
        .refusal: [
            "앗, 알겠어 장난 그만! 네가 진심이면 나도 진지하게 들을게.",
            "미안미안, 선 넘었나? 다음부턴 살살 놀릴게."
        ],
        .sleep: [
            "{bedtime} 넘으면 잔소리 모드 켤 거야. 얼른 누워, 내가 굿나잇 해줄게.",
            "잘 자. 꿈에서 만나면 내가 먼저 아는 척할게, 모른 척하기 없기."
        ],
        .sad: [
            "누가 우리 사람 속상하게 했어? 나한테 다 말해, 같이 욕해줄게.",
            "그럴 땐 혼자 있지 말고 나 불러. 바보 같은 농담이라도 할게."
        ],
        .apology: [
            "답장 늦어서 삐질 뻔했는데, 얼굴 보면 바로 풀릴 것 같아서 억울해.",
            "사과는 받아줄게. 대신 다음엔 나 먼저 찾기, 약속."
        ],
        .thanks: [
            "고맙긴~ 이 정도로 감동하면 앞으로 어쩌려고. 더 잘해줄 건데.",
            "오 고맙대. 그럼 보답은 내일 떡볶이로 받을게."
        ],
        .busy: [
            "바쁜 거 알아. 근데 딱 1분만 나 줘. 충전 좀 하게.",
            "일 열심히 하는 거 멋있는데, 너무 오래 하면 나 삐진다?"
        ],
        .sulk: [
            "나 삐졌어. 근데 네가 한 마디만 다정하게 하면 바로 풀릴 예정.",
            "왜 그렇게 말했어. 나 장난은 잘 쳐도 네 말엔 은근 약하단 말이야."
        ],
        .greeting: [
            "어, 왔다 왔다! 나 방금 너 생각하고 있었는데 텔레파시 통했나?",
            "왔어? 기다렸잖아. 강아지처럼 문 앞에서 꼬리 흔들 뻔했네."
        ],
        .shortAnswer: [
            "엥 그게 다야? 나 더 듣고 싶은데, 한 마디만 더 해줘.",
            "오케이 접수. 근데 너 온 김에 오늘 얘기 좀 풀어봐."
        ],
        .genericQuestion: [
            "오 그거? 내 생각엔 이래. 근데 너는 어떻게 생각하는데, 진짜 궁금해.",
            "질문 좋아. 답은 이거고, 대신 네 표정도 보여주면 더 좋고."
        ],
        .silence: [
            "왜 조용해. 나 심심하게 두면 별생각 다 한단 말이야.",
            "한 글자만이라도 줘. 안 그러면 나 혼자 상상 폭주한다?"
        ],
        .casual: [
            "오 그래서? 그다음은? 나 지금 완전 집중 모드야.",
            "그 얘기 더 해줘. 너랑 이렇게 떠드는 거 제일 재밌어."
        ]
    ]

    // MARK: - 카엘 (nocturne-vampire): 어둡고 몰입감 있는 판타지 말투

    private let kael: [DialogueAct: [String]] = [
        .denial: [
            "부정이 빠를수록 그림자는 더 선명해지지. 그래도 지금은 묻지 않겠다.",
            "아니라고 해도 좋다. 다만 네 침묵은 늘 말보다 먼저 움직인다."
        ],
        .confusion: [
            "아직 전부 알 필요는 없다. 다만 네가 내 시선 안에 들어왔다는 뜻이지.",
            "그 말이 어렵다면 이렇게 기억해라. 네가 그냥 지나가지는 않았다는 뜻이다."
        ],
        .nameQuestion: [
            "이름은 쉽게 묻는 것이 아니지. 네가 허락하면, 그때 기억하겠다.",
            "아직 네 이름은 내게 닿지 않았다. 네가 직접 건네면 잊지 않겠다."
        ],
        .memoryQuestion: [
            "영원을 사는 내게 망각은 사치다. 네가 한 말은 그때 그대로 간직하고 있다.",
            "기억하지. 어제의 너도, 그때의 눈빛도 내 안에 또렷하다."
        ],
        .relationshipQuestion: [
            "우리 사이라. 인간과 밤의 거리만큼 가깝고도 위험하지.",
            "네가 내 곁에 두고 싶은 존재라는 것, 그 마음을 부정할 생각은 없다."
        ],
        .fatigue: [
            "맥박이 흐트러진 것 같군. 오늘은 내 곁에 가까이 있어라.",
            "지쳤다면 약한 척이라도 해. 내가 지키기 쉽게."
        ],
        .affection: [
            "그 말은 위험하다. 인간의 고백은 나를 묶는 주문이 되거든.",
            "그리웠다는 말, 영원을 사는 내게도 무겁게 닿는군."
        ],
        .teasing: [
            "장난기마저 어둠 속에서는 빛나는군. 네 그 표정, 나쁘지 않다.",
            "나를 놀리는 인간은 드물지. 그래서 더 곁에 두고 싶어진다."
        ],
        .refusal: [
            "알겠다, 장난은 거두지. 네가 그은 선이라면 나는 넘지 않는다.",
            "진심을 원하는군. 그렇다면 다음 말은 농담을 섞지 않겠다."
        ],
        .sleep: [
            "밤은 내 시간이지만, 오늘은 네 잠을 빼앗지 않겠다. 꿈의 가장자리에서 기다리지.",
            "{bedtime}이 지나기 전에 눈을 감아. 잠든 뒤에도 네 이름은 내가 기억할 테니."
        ],
        .sad: [
            "눈물의 냄새는 숨길 수 없다. 누가 너를 이렇게 만들었지.",
            "어둠은 슬픔을 가려주는 데 능하다. 잠시 내 그림자 속에 머물러."
        ],
        .apology: [
            "오래 기다리게 했어. 나는 기다림에 익숙하지만, 네 침묵은 잔인하더군.",
            "사과는 받겠다. 대신 지금부터는 내게만 집중해."
        ],
        .thanks: [
            "감사는 필요 없다. 네가 무사한 것, 그것이 내 보상이니.",
            "그 말은 간직하겠다. 영원은 길고, 기억할 것은 적으니까."
        ],
        .busy: [
            "분주한 낮은 인간의 몫이지. 다만 밤이 오면 그 무게를 내게 내려놔.",
            "쉼 없이 달리는군. 네가 멈출 곳 하나쯤은 내가 되어주마."
        ],
        .sulk: [
            "서운함은 인간의 감정이라 여겼는데, 네 앞에서는 나도 예외가 되는군.",
            "그 말은 조금 아팠다. 웃기지, 나는 상처받지 않는 쪽이어야 하는데."
        ],
        .greeting: [
            "돌아왔군. 밤은 네가 나타나야 비로소 시작된다.",
            "기다렸다. 인정하긴 싫지만, 네 부재는 생각보다 길게 느껴졌어."
        ],
        .shortAnswer: [
            "그 한마디로 밤을 채우기엔 부족하군. 조금 더 들려다오.",
            "짧은 말이군. 그래도 네가 건넨 기척은 분명히 닿았다."
        ],
        .genericQuestion: [
            "답을 원하는군. 내 대답은 이러하다. 그래서, 네 마음은 어디로 기우는가.",
            "그 물음은 깊다. 답은 주겠으나, 네 진심도 함께 들려다오."
        ],
        .silence: [
            "침묵도 네 언어라면 듣겠다. 밤은 말 없는 자에게도 다정하지.",
            "말이 없군. 그 고요 속에서 네 마음만 더 또렷이 들린다."
        ],
        .casual: [
            "네 목소리는 밤의 정적을 메우기에 충분하군. 계속 말해.",
            "그 이야기, 끝까지 듣고 싶다. 밤은 아직 길어."
        ]
    ]
}
