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
        _ = ConversationPromptContextBuilder.build(context: context)
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
        if t.contains("슬프") || t.contains("우울") || t.contains("속상") || t.contains("울고") || t.contains("외로") || t.contains("무서") { return .sad }
        if t.contains("바빠") || t.contains("바쁘") || t.contains("회의") || t.contains("야근") || t.contains("공부") { return .busy }
        if t.contains("잘게") || t.contains("자야") || t.contains("굿나잇") || t.contains("잘자")
            || t.contains("잘래") || t.contains("졸려") || t.contains("잠이 안") || t.contains("잠 안")
            || t.contains("잠 못") || t.contains("잠들지") { return .sleep }
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
    case userNameIntroduction
    case userNameCorrection
    case askKnownUserName
    case askKnownUserIdentity
    // 직전 답변이 질문 대상을 잘못 이해했을 때 유저가 바로잡는 발화("니 이름 말고 내 이름").
    case clarificationCorrection
    case characterIdentityQuestion
    case userIdentityQuestion
    case characterCall
    case nameQuestion
    case memoryQuestion
    case relationshipQuestion
    case confusion
    case greeting
    // 유저가 자기 식사/활동을 알리는 경우(subject=user).
    case userFoodDisclosure
    case userActivityDisclosure
    // 유저가 캐릭터 자신에게 묻는 질문(subject=character, target=currentCharacter).
    case characterFoodQuestion
    case characterPreferenceQuestion
    case characterStateQuestion
    case characterActivityQuestion
    case invitationOrPlanProposal
    // 유저가 대화를 끝내고 자러 간다고 알리는 경우(subject=user, topic=sleep).
    case farewellOrSleep
    case dailyLife
    case bullyingOrHarassment
    case physicalHarm
    case fear
    case sadness
    case fatigue
    case affection
    case emotionalDisclosure
    case selfDisclosure
    case casual
    case unknown

    /// 안전(보호) 우선 사건 — 장난 톤을 줄이고 보호·안전 확인을 앞세운다.
    var isSafetyEvent: Bool {
        self == .bullyingOrHarassment || self == .physicalHarm
    }

    var requiresChatPrimaryRoute: Bool {
        switch self {
        case .userNameIntroduction, .userNameCorrection, .askKnownUserName, .askKnownUserIdentity,
             .clarificationCorrection,
             .characterIdentityQuestion, .userIdentityQuestion, .characterCall, .nameQuestion,
             .memoryQuestion, .relationshipQuestion, .confusion,
             .userFoodDisclosure, .userActivityDisclosure,
             .characterFoodQuestion, .characterPreferenceQuestion, .characterStateQuestion, .characterActivityQuestion,
             .invitationOrPlanProposal, .farewellOrSleep,
             .bullyingOrHarassment, .physicalHarm:
            return true
        default:
            return false
        }
    }

    var logName: String {
        switch self {
        case .userNameIntroduction: return "userNameIntroduction"
        case .userNameCorrection: return "userNameCorrection"
        case .askKnownUserName: return "askKnownUserName"
        case .askKnownUserIdentity: return "askKnownUserIdentity"
        case .clarificationCorrection: return "clarificationCorrection"
        case .characterIdentityQuestion: return "characterIdentityQuestion"
        case .userIdentityQuestion: return "userIdentityQuestion"
        case .characterCall: return "characterCall"
        case .nameQuestion: return "nameQuestion"
        case .memoryQuestion: return "memoryQuestion"
        case .relationshipQuestion: return "relationshipQuestion"
        case .confusion: return "confusion"
        case .greeting: return "greeting"
        case .userFoodDisclosure: return "userFoodDisclosure"
        case .userActivityDisclosure: return "userActivityDisclosure"
        case .characterFoodQuestion: return "characterFoodQuestion"
        case .characterPreferenceQuestion: return "characterPreferenceQuestion"
        case .characterStateQuestion: return "characterStateQuestion"
        case .characterActivityQuestion: return "characterActivityQuestion"
        case .invitationOrPlanProposal: return "invitationOrPlanProposal"
        case .farewellOrSleep: return "farewellOrSleep"
        case .dailyLife: return "dailyLife"
        case .bullyingOrHarassment: return "bullyingOrHarassment"
        case .physicalHarm: return "physicalHarm"
        case .fear: return "fear"
        case .sadness: return "sadness"
        case .fatigue: return "fatigue"
        case .affection: return "affection"
        case .emotionalDisclosure: return "emotionalDisclosure"
        case .selfDisclosure: return "selfDisclosure"
        case .casual: return "casual"
        case .unknown: return "unknown"
        }
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

/// 현재 턴이 "누구에 대한" 발화인지. food/activity/preference/state를 user/character로 가르는 핵심 축.
enum MessageSubject {
    case user
    case character
    case both
    case relationship
    case unknown

    var logName: String {
        switch self {
        case .user: return "user"
        case .character: return "character"
        case .both: return "both"
        case .relationship: return "relationship"
        case .unknown: return "unknown"
        }
    }
}

/// 발화가 "누구를 향하는지"(답변 대상).
enum MessageTarget {
    case currentCharacter
    case user
    case relationship
    case world
    case unknown

    var logName: String {
        switch self {
        case .currentCharacter: return "currentCharacter"
        case .user: return "user"
        case .relationship: return "relationship"
        case .world: return "world"
        case .unknown: return "unknown"
        }
    }
}

/// 발화의 주제.
enum MessageTopic {
    case food
    case activity
    case preference
    case state
    case identity
    case name
    case emotion
    case safety
    case plan
    case sleep
    case casual
    case unknown

    var logName: String {
        switch self {
        case .food: return "food"
        case .activity: return "activity"
        case .preference: return "preference"
        case .state: return "state"
        case .identity: return "identity"
        case .name: return "name"
        case .emotion: return "emotion"
        case .safety: return "safety"
        case .plan: return "plan"
        case .sleep: return "sleep"
        case .casual: return "casual"
        case .unknown: return "unknown"
        }
    }
}

/// 유저 마지막 메시지에 대한 종합 이해. 사건·감정·기대 반응·반복 여부에 더해
/// "현재 턴의 주체(subject)/대상(target)/주제(topic)"까지 담아, 직전 맥락이 현재 질문을 덮어쓰지 못하게 한다.
struct UserMessageUnderstanding {
    let rawText: String
    /// 띄어쓰기/문장부호를 제거한 정규화 텍스트. "내이름" vs "내 이름"을 같은 의도로 본다.
    let normalizedText: String
    let dialogueAct: DialogueAct
    let eventType: EventType
    let subject: MessageSubject
    let target: MessageTarget
    let topic: MessageTopic
    let emotion: String?
    let keyEvent: String?
    let keyObject: String?
    let extractedUserName: String?
    let knownUserName: String?
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
    private static let foodTokens = ["먹었", "먹음", "먹어", "뭐 먹", "뭘 먹", "맛", "햄버거", "밥 먹", "치킨", "피자", "라면", "떡볶이", "먹는 중", "먹고 있"]
    private static let greetingTokens = ["안녕", "하이", "왔어", "할로", "헬로"]
    private static let dailyLifeTokens = ["뭐해", "뭐 해", "너는 뭐", "넌 뭐", "뭐하고", "뭐 하고", "지금 뭐"]
    /// 제안/초대/계획. "우리 내일 놀이동산가자", "같이 가자", "옆에 있어줘" 등.
    private static let invitationTokens = [
        "놀이동산", "놀러 가", "놀러가", "같이 가", "같이가", "만나자", "데이트",
        "같이 있을래", "같이있을래", "옆에 있어", "옆에있어", "같이 밥 먹", "같이 밥먹",
        "보러 가", "보러가", "여행 가", "여행가", "같이 보자", "같이 하자", "함께 가",
        "가자", "하러 가", "구경 가", "산책 가", "영화 보러"
    ]
    private static let characterIdentityTokens = [
        "너는 누구야", "넌 누구야", "너 누구", "너 정체가 뭐야", "너 뭐야", "넌 뭐야", "정체가 뭐",
        // 캐릭터의 "이름"을 묻는 패턴(유저 이름 질문 "내 이름"과 구분됨).
        "너 이름", "너의 이름", "니 이름", "니이름", "네 이름은", "네 이름이", "네 이름 뭐", "이름이 뭐야", "이름 뭐야", "이름이 뭐니"
    ]
    /// 유저가 대화를 끝내고 자러 간다고 알리는 인사/취침 신호.
    private static let farewellTokens = [
        "이만 잘", "이만 갈", "이만 가볼", "자러 갈", "자러 간", "자야겠", "잘래", "잘게",
        "굿나잇", "굿 나잇", "잘 자", "잘자", "잘 자라", "꿈나라", "들어가서 잘", "이제 잘", "이제 자", "그만 자"
    ]
    private static let askKnownUserIdentityTokens = [
        "내가 누구라고", "나 누구라고", "내가 누구였지", "나 누구였지",
        "나 누구라고 했지", "방금 나 누구라고", "내가 누구야", "나 누구야",
        "내가 누구게", "나 누구게"
    ]
    private static let userIdentityTokens = [
        "내가 누군지 알아", "나 알아?", "나 알아"
    ]
    private static let askKnownUserNameTokens = [
        "내 이름이 뭐야", "내 이름 뭐야", "내 이름이 뭐", "내 이름 뭐",
        "내 이름이 뭐라고", "내 이름 뭐라고", "내 이름이 뭐였지", "내 이름 뭐였지",
        "내 이름 다시 말해", "내 이름 기억나", "내 이름 기억해", "내 이름 알아",
        "나 이름 뭐였지", "나 이름 뭐라고", "이름 기억나"
    ]
    private static let nameQuestionTokens = [
        "내 이름 알아", "내 이름 기억해", "내 이름 뭐야", "이름 알아", "이름 기억해", "이름 뭐야"
    ]
    private static let memoryQuestionTokens = ["기억나", "기억해", "기억하", "기억 안", "기억 못"]
    private static let relationshipQuestionTokens = ["무슨 사이", "우리 사이", "우리 무슨", "나 어떻게 생각", "날 어떻게 생각"]
    private static let confusionTokens = ["무슨 소리", "뭔 소리", "뭔데", "무슨 말", "뭔 말", "모르겠", "헷갈", "이해 안", "이해가 안"]

    /// 띄어쓰기·문장부호를 제거하고 소문자화한 정규화 문자열.
    /// "내이름이 뭐야"와 "내 이름이 뭐야"를 동일한 의도로 인식하기 위함.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let kept = lowered.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.punctuationCharacters.contains(scalar)
                && !CharacterSet.symbols.contains(scalar)
        }
        return String(String.UnicodeScalarView(kept))
    }

    static func analyze(
        userLastMessage: String,
        previousUserMessage: String,
        previousCharacterMessage: String,
        avatarKey: String,
        knownUserName: String? = nil
    ) -> UserMessageUnderstanding {
        let t = userLastMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = normalize(t)
        let correctionName = extractNameCorrectionName(from: t, knownUserName: knownUserName)
        let introductionName = extractSelfIntroductionName(from: t, knownUserName: knownUserName)
        let extractedName = correctionName ?? introductionName
        let dialogueAct = DialogueActDetector.detect(
            userLastMessage: userLastMessage,
            previousCharacterMessage: previousCharacterMessage,
            avatarKey: avatarKey
        )

        let isPhysicalHarm = physicalHarmTokens.contains { t.contains($0) }
        let isBullying = bullyingTokens.contains { t.contains($0) }
        let prevWasSafety = (physicalHarmTokens + bullyingTokens).contains { previousUserMessage.contains($0) }
        let characterName = displayName(for: avatarKey)
        let isCharacterCall = t == "\(characterName)아" || t == "\(characterName)야"

        // 현재 턴의 주체/주제 신호. "너/넌/너는/너도/네가/캐릭터이름"이 주어로 들어오면
        // 직전 맥락과 무관하게 "캐릭터 자신에게 묻는 질문"으로 본다(subject=character).
        let mentionsCharacterSubject = ["너는", "넌", "너도", "네가", "너 "].contains { t.contains($0) }
            || (!characterName.isEmpty && ["\(characterName)은", "\(characterName)는", "\(characterName)도", "\(characterName)이"].contains { t.contains($0) })
        let isFoodTopic = foodTokens.contains { t.contains($0) }
        let isPreferenceTopic = ["좋아해", "좋아하", "좋아?", "싫어해", "싫어하", "취향", "즐겨"].contains { t.contains($0) }
        let isStateTopic = ["배고프", "배 안 고", "배고파", "괜찮아", "피곤", "졸려", "졸리", "지쳤", "지쳐"].contains { t.contains($0) }
        let isActivityTopic = dailyLifeTokens.contains { t.contains($0) }
            || ["뭐 했", "뭐했", "하고 있", "하는 중", "뭐 하고", "뭐하고",
                "뭐할", "뭐 할", "뭐 할 거", "뭐할 거", "뭐 할거", "뭐할거", "할 거야", "할거야", "뭐 하니"].contains { t.contains($0) }

        // 정규화 텍스트 기반 이름-주체 신호. "내이름"(붙여 쓴 경우 포함)은 유저 이름 질문,
        // "너이름/니이름"은 캐릭터 이름 질문으로 구분한다.
        let mentionsMyName = ["내이름", "나이름", "제이름", "내이릅"].contains { n.contains($0) }
        let mentionsYourName = ["너이름", "니이름", "네이름", "너의이름", "당신이름"].contains { n.contains($0) }
        let hasContrastMarker = n.contains("말고") || n.contains("아니라") || n.contains("그게아니")
        // "니 이름 말고 내 이름"처럼 직전 답변이 질문 대상을 잘못 짚었을 때 유저가 바로잡는 발화.
        let isClarificationCorrection =
            (mentionsMyName && (mentionsYourName || hasContrastMarker))
            || ["너말고나", "니말고나", "당신말고나", "내이름물어", "내이름말고", "니이름말고", "너이름말고", "네이름말고", "말고내이름"].contains { n.contains($0) }
        // "내 이름이 뭐야" 류 — 정규화로 붙여 쓴 변형까지 잡는다.
        let asksMyName = mentionsMyName
            && (n.contains("뭐") || n.contains("기억") || n.contains("알아") || n.contains("말해") || n.contains("아니") || n.contains("불러"))

        let eventType: EventType
        let response: ExpectedResponseType
        let emotion: String?
        let severity: EventSeverity
        var requiresDirectAnswer = false
        var keyObject: String? = nil

        // 우선순위: physicalHarm > bullying > name correction > name introduction > known-name/identity recall > character identity > character call > 이름/기억/관계 질문 > confusion > food > greeting > fatigue > affection > dailyLife > casual.
        if isPhysicalHarm {
            eventType = .physicalHarm; response = .protect; emotion = "hurt"; severity = .safety
        } else if isBullying {
            eventType = .bullyingOrHarassment; response = .protect; emotion = "hurt"; severity = .safety
        } else if correctionName != nil {
            eventType = .userNameCorrection; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if introductionName != nil {
            eventType = .userNameIntroduction; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if isClarificationCorrection {
            // "니 이름 말고 내 이름" → 직전 답을 바로잡고, 원래 의도(유저 이름 묻기)로 다시 답해야 한다.
            eventType = .clarificationCorrection; response = .clarifyPrevious; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if asksMyName || askKnownUserNameTokens.contains(where: { n.contains(normalize($0)) }) {
            eventType = .askKnownUserName; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if askKnownUserIdentityTokens.contains(where: { n.contains(normalize($0)) }) {
            eventType = .askKnownUserIdentity; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if !mentionsMyName && characterIdentityTokens.contains(where: { n.contains(normalize($0)) }) {
            eventType = .characterIdentityQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if userIdentityTokens.contains(where: { t.contains($0) }) {
            eventType = .userIdentityQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if isCharacterCall {
            eventType = .characterCall; response = .greetBack; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if nameQuestionTokens.contains(where: { t.contains($0) }) || t.contains("이름") {
            eventType = .nameQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if memoryQuestionTokens.contains(where: { t.contains($0) }) {
            eventType = .memoryQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if relationshipQuestionTokens.contains(where: { t.contains($0) }) {
            eventType = .relationshipQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if confusionTokens.contains(where: { t.contains($0) }) {
            eventType = .confusion; response = .clarifyPrevious; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if mentionsCharacterSubject && isPreferenceTopic {
            // "너도 햄버거 좋아해?" → 캐릭터 자신의 취향에 답해야 한다.
            eventType = .characterPreferenceQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if mentionsCharacterSubject && isFoodTopic {
            // "너는 뭐 먹었어?" → 직전 유저 음식이 아니라, 캐릭터 자신이 무엇을 먹는지/먹지 않는지에 답해야 한다.
            eventType = .characterFoodQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if mentionsCharacterSubject && isStateTopic {
            // "너 배고프지 않아?" → 캐릭터 자신의 상태에 답해야 한다.
            eventType = .characterStateQuestion; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if mentionsCharacterSubject && isActivityTopic {
            // "너는 뭐 했어?" → 캐릭터 자신이 무엇을 하고 있었는지에 답해야 한다.
            eventType = .characterActivityQuestion; response = .continueStory; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if invitationTokens.contains(where: { t.contains($0) }) {
            // "우리 내일 놀이동산가자" → 제안에 수락/망설임/조건/감정으로 반응해야 한다(주제=계획).
            eventType = .invitationOrPlanProposal; response = .answerQuestion; emotion = nil; severity = .none; requiresDirectAnswer = true
        } else if foodTokens.contains(where: { t.contains($0) }) {
            // 주체가 유저인 음식 이야기(나 햄버거 먹었어).
            eventType = .userFoodDisclosure; response = .askTasteOrShare; emotion = "content"; severity = .none
            keyObject = ["햄버거", "치킨", "피자", "라면", "떡볶이", "국밥", "김밥", "초밥", "파스타", "스테이크",
                         "샐러드", "샌드위치", "볶음밥", "도시락", "국수", "쌀국수", "비빔밥", "찌개", "탕", "빵"]
                .first { t.contains($0) }
        } else if greetingTokens.contains(where: { t.contains($0) }) {
            eventType = .greeting; response = .greetBack; emotion = nil; severity = .none
        } else if farewellTokens.contains(where: { t.contains($0) }) {
            // "나는 이만 잘게" → greeting이 아니라 자러 가는 유저에게 쉬라고 답해야 한다.
            eventType = .farewellOrSleep; response = .comfort; emotion = nil; severity = .none
        } else if t.contains("피곤") || t.contains("졸려") || t.contains("지쳤") || t.contains("지쳐") || t.contains("힘들")
            || t.contains("잠이 안") || t.contains("잠 안") || t.contains("잠 못") || t.contains("잠들지") {
            eventType = .fatigue; response = .comfort; emotion = "tired"; severity = .elevated
        } else if t.contains("무서") || t.contains("두려") || t.contains("겁나") {
            eventType = .fear; response = .comfort; emotion = "fear"; severity = .elevated
        } else if t.contains("슬프") || t.contains("우울") || t.contains("속상") || t.contains("울고") || t.contains("외로") {
            eventType = .sadness; response = .comfort; emotion = "sad"; severity = .elevated
        } else if t.contains("보고 싶") || t.contains("보고싶") || t.contains("좋아") || t.contains("생각났") || t.contains("사랑") {
            eventType = .affection; response = .teaseLightly; emotion = "fond"; severity = .none
        } else if dailyLifeTokens.contains(where: { t.contains($0) }) {
            eventType = .dailyLife; response = .continueStory; emotion = nil; severity = .none
        } else if ["나는", "내가", "나 ", "오늘 나", "나도"].contains(where: { t.hasPrefix($0) || t.contains($0) })
            && ["있었", "갔어", "왔어", "했어", "지냈", "보냈"].contains(where: { t.contains($0) }) {
            // "나 오늘 집에만 있었어" 처럼 유저가 자기 활동을 알리는 경우.
            eventType = .userActivityDisclosure; response = .continueStory; emotion = nil; severity = .none
        } else if t.isEmpty {
            eventType = .unknown; response = .continueStory; emotion = nil; severity = .none
        } else {
            eventType = .casual; response = .continueStory; emotion = nil; severity = .none
        }

        // 같은 안전 사건을 다시 말하면 반복 해명으로 본다("~다니까", "~라니까" 강조 포함).
        let repeatedMarker = t.contains("니까") || t.contains("라고") || t.contains("다니까")
        let isRepeated = eventType.isSafetyEvent && (prevWasSafety || repeatedMarker)

        let subject = subjectFor(eventType)
        let target = targetFor(eventType)
        let topic = topicFor(eventType)

        return UserMessageUnderstanding(
            rawText: t,
            normalizedText: n,
            dialogueAct: dialogueAct,
            eventType: eventType,
            subject: subject,
            target: target,
            topic: topic,
            emotion: emotion,
            keyEvent: eventType.isSafetyEvent ? "harm" : nil,
            keyObject: keyObject,
            extractedUserName: extractedName,
            knownUserName: knownUserName,
            expectedResponseType: response,
            isRepeatedClarification: isRepeated,
            requiresDirectAnswer: requiresDirectAnswer,
            severity: severity
        )
    }

    /// 사건(EventType)으로부터 현재 턴의 주체를 도출한다.
    private static func subjectFor(_ event: EventType) -> MessageSubject {
        switch event {
        case .characterFoodQuestion, .characterPreferenceQuestion, .characterStateQuestion,
             .characterActivityQuestion, .characterIdentityQuestion, .characterCall, .greeting:
            return .character
        case .userFoodDisclosure, .userActivityDisclosure, .userNameIntroduction, .userNameCorrection,
             .userIdentityQuestion, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection, .nameQuestion,
             .bullyingOrHarassment, .physicalHarm, .fear, .sadness, .fatigue, .farewellOrSleep,
             .selfDisclosure, .emotionalDisclosure:
            return .user
        case .relationshipQuestion, .affection, .invitationOrPlanProposal:
            return .relationship
        case .memoryQuestion:
            return .both
        default:
            return .unknown
        }
    }

    /// 사건으로부터 답변이 향해야 하는 대상을 도출한다.
    private static func targetFor(_ event: EventType) -> MessageTarget {
        switch event {
        case .characterFoodQuestion, .characterPreferenceQuestion, .characterStateQuestion,
             .characterActivityQuestion, .characterIdentityQuestion, .characterCall:
            return .currentCharacter
        case .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection, .userIdentityQuestion, .nameQuestion, .memoryQuestion,
             .farewellOrSleep:
            return .user
        case .relationshipQuestion, .affection, .invitationOrPlanProposal:
            return .relationship
        default:
            return .unknown
        }
    }

    /// 사건으로부터 주제를 도출한다.
    private static func topicFor(_ event: EventType) -> MessageTopic {
        switch event {
        case .invitationOrPlanProposal: return .plan
        case .farewellOrSleep: return .sleep
        case .characterFoodQuestion, .userFoodDisclosure: return .food
        case .characterActivityQuestion, .userActivityDisclosure, .dailyLife: return .activity
        case .characterPreferenceQuestion: return .preference
        case .characterStateQuestion: return .state
        case .characterIdentityQuestion, .userIdentityQuestion: return .identity
        case .nameQuestion, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection, .userNameIntroduction, .userNameCorrection: return .name
        case .bullyingOrHarassment, .physicalHarm: return .safety
        case .fear, .sadness, .fatigue, .affection, .emotionalDisclosure, .selfDisclosure: return .emotion
        case .greeting, .casual: return .casual
        default: return .unknown
        }
    }

    static func extractSelfIntroductionName(from text: String, knownUserName: String? = nil) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if extractNameCorrectionName(from: trimmed, knownUserName: knownUserName) != nil {
            return nil
        }

        let patterns = [
            #"^나는\s+(.+?)(?:이야|야|이다|입니다)$"#,
            #"^나\s+(.+?)(?:이야|야|이다|입니다)$"#,
            #"^내\s*이름은\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^내\s*이름\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^(.+?)(?:이라고|라고)\s*불러$"#,
            #"^(.+?)(?:이라고|라고)$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range),
                  match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: trimmed)
            else { continue }
            let candidate = normalizeName(String(trimmed[captureRange]))
            if isPlausibleName(candidate) { return candidate }
        }
        return nil
    }

    static func extractNameCorrectionName(from text: String, knownUserName: String? = nil) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let correctionPatterns = [
            #"^내\s*이름은\s*사실\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^내\s*이름은\s*진짜\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^아니\s*내\s*이름은\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^아니야\s*내\s*이름은\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^사실은\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^사실\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^(.+?)\s*아니고\s+(.+?)(?:이야|야|이다|입니다)?$"#,
            #"^(.+?)\s*말고\s+(.+?)(?:이야|야|이다|입니다)?$"#
        ]

        for pattern in correctionPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range) else { continue }
            let captureIndex = match.numberOfRanges >= 3 ? 2 : 1
            guard let captureRange = Range(match.range(at: captureIndex), in: trimmed) else { continue }
            let candidate = normalizeName(String(trimmed[captureRange]))
            if isPlausibleName(candidate) { return candidate }
        }

        guard let knownUserName,
              let calledName = extractCallName(from: trimmed),
              calledName != knownUserName
        else { return nil }
        return calledName
    }

    private static func extractCallName(from text: String) -> String? {
        let patterns = [
            #"^(.+?)(?:이라고|라고)\s*불러$"#,
            #"^(.+?)(?:이라고|라고)$"#,
            #"^내\s*이름은\s+(.+?)(?:이야|야|이다|입니다)?$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: text)
            else { continue }
            let candidate = normalizeName(String(text[captureRange]))
            if isPlausibleName(candidate) { return candidate }
        }
        return nil
    }

    private static func normalizeName(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = ["이라고 불러", "라고 불러", "이라고", "라고", "입니다", "이다", "이야", "야", "은", "는"]
        var didTrim = true
        while didTrim {
            didTrim = false
            for suffix in suffixes where result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                didTrim = true
            }
        }
        return result
    }

    private static func isPlausibleName(_ value: String) -> Bool {
        guard value.count >= 1, value.count <= 12 else { return false }
        let blocked = ["누구", "뭐", "사람", "인간", "너", "나", "내", "카엘", "한아", "서윤", "로이"]
        if blocked.contains(value) { return false }
        return !value.contains(" ") && value.rangeOfCharacter(from: .decimalDigits) == nil
    }

    private static func displayName(for avatarKey: String) -> String {
        switch avatarKey {
        case "ice-boss": return "한아"
        case "sunny-friend": return "서윤"
        case "puppy-junior": return "로이"
        case "nocturne-vampire": return "카엘"
        default: return ""
        }
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
            avatarKey: flow.avatarKey,
            knownUserName: context.memory.userName
        )

        // 사건(EventType)으로 먼저 이해되는 메시지는 DialogueAct 분기보다 먼저 사건에 직접 반응한다.
        // 안전 사건(괴롭힘/폭력)은 물론, greeting/food/dailyLife도 유저 메시지에 직접 연결되도록 사건 경로로 처리.
        switch understanding.eventType {
        case .userNameIntroduction, .userNameCorrection, .askKnownUserName, .askKnownUserIdentity,
             .clarificationCorrection,
             .characterIdentityQuestion, .userIdentityQuestion, .characterCall, .nameQuestion, .memoryQuestion, .relationshipQuestion,
             .confusion, .greeting, .userFoodDisclosure, .userActivityDisclosure,
             .characterFoodQuestion, .characterPreferenceQuestion, .characterStateQuestion, .characterActivityQuestion,
             .invitationOrPlanProposal, .farewellOrSleep,
             .dailyLife, .fear, .sadness, .fatigue, .emotionalDisclosure, .bullyingOrHarassment, .physicalHarm:
            let extractedLog = understanding.extractedUserName.map { " extractedName=\"\($0)\"" } ?? ""
            let knownLog = understanding.knownUserName.map { " knownName=\"\($0)\"" } ?? ""
            print("[StoryUnderstanding] character=\(characterLogKey(flow.avatarKey)) event=\(understanding.eventType.logName) subject=\(understanding.subject.logName) target=\(understanding.target.logName) topic=\(understanding.topic.logName)\(extractedLog)\(knownLog) requiresDirectAnswer=\(understanding.requiresDirectAnswer) repeated=\(understanding.isRepeatedClarification) user=\"\(flow.userLastMessage)\"")
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
        if let direct = memoryAwareDirectReply(flow: flow, context: context, understanding: understanding) {
            return direct
        }

        let candidates = eventCandidates(avatarKey: flow.avatarKey, understanding: understanding)
        let eventTag = understanding.eventType.logName
        // 유저가 말한 실제 음식명을 응답에 그대로 반영(피자라고 했는데 햄버거라고 답하지 않도록).
        let foodWord = understanding.keyObject ?? "그거"

        var fallback = fillFood(personalize(candidates.first ?? eventFallbackLine(understanding.eventType), flow: flow), foodWord: foodWord)
        for candidate in rotated(candidates, seed: flow.seed + eventTag + "\(understanding.isRepeatedClarification)") {
            let line = fillFood(personalize(candidate, flow: flow), foodWord: foodWord)
            if line != flow.previousCharacterMessage {
                fallback = line
            }
            let verdict = evaluator.evaluate(line, against: context, understanding: understanding)
            if verdict.isAccepted, line != flow.previousCharacterMessage {
                print("[StoryReply] character=\(characterLogKey(flow.avatarKey)) event=\(eventTag) quality=pass reply=\"\(line)\"")
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
        case .userNameIntroduction, .userNameCorrection, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection: return []
        case .characterIdentityQuestion: return tables.characterIdentity
        case .userIdentityQuestion: return tables.userIdentity
        case .characterCall: return tables.characterCall
        case .nameQuestion: return tables.nameQuestion
        case .memoryQuestion: return tables.memoryQuestion
        case .relationshipQuestion: return tables.relationshipQuestion
        case .confusion: return tables.confusion
        case .fatigue: return fatigueCandidates(avatarKey: avatarKey)
        case .fear, .sadness, .emotionalDisclosure: return tables.comfort
        case .greeting: return tables.greeting
        case .userFoodDisclosure: return tables.food
        case .characterFoodQuestion: return tables.characterFoodAnswer
        case .characterPreferenceQuestion: return tables.characterPreferenceAnswer
        case .characterStateQuestion: return tables.characterStateAnswer
        case .characterActivityQuestion: return tables.dailyLife
        case .userActivityDisclosure: return tables.userActivityAck
        case .invitationOrPlanProposal: return tables.invitationProposal
        case .farewellOrSleep: return tables.farewell
        case .dailyLife: return tables.dailyLife
        case .bullyingOrHarassment: return understanding.isRepeatedClarification ? tables.bullyingRepeated : tables.bullyingSupport
        case .physicalHarm: return understanding.isRepeatedClarification ? tables.physicalHarmRepeated : tables.physicalHarm
        default: return tables.dailyLife
        }
    }

    private func eventFallbackLine(_ event: EventType) -> String {
        switch event {
        case .physicalHarm: return "맞았다고? 지금 안전한 곳인지, 다친 데는 없는지부터 말해."
        case .bullyingOrHarassment: return "누가 그랬어. 혼자 넘기지 말고 말해, 네 편이니까."
        case .userNameIntroduction: return "알겠다. 그 이름으로 기억하겠다."
        case .userNameCorrection: return "알겠다. 이번엔 그 이름으로 바로잡아 기억하겠다."
        case .askKnownUserName: return "아직은 모른다. 네가 알려주면, 다음엔 그 이름으로 부르겠다."
        case .askKnownUserIdentity: return "아직 네 이름은 모른다. 알려주면 다음엔 제대로 답하겠다."
        case .clarificationCorrection: return "아, 네 이름을 물은 거였구나. 아직은 모르니까 알려주면 그걸로 부를게."
        case .characterIdentityQuestion: return "나는 네 이야기를 듣는 사람이다. 이름부터 말하자면, {name}."
        case .userIdentityQuestion: return "네가 누구냐고? 내가 기다리던 사람이지. 그래도 네 이름은 네 입으로 듣고 싶어."
        case .characterCall: return "그래, 여기 있다. 네 부름은 들었다. 무슨 일이지."
        case .nameQuestion: return "아직은 모른다. 네가 알려주면, 다음엔 그 이름으로 부르겠다."
        case .memoryQuestion: return "기억하고 싶어. 네가 말해준 건 가볍게 넘기지 않을게."
        case .relationshipQuestion: return "우리 사이를 묻는다면, 적어도 그냥 스쳐 가는 사이는 아니야."
        case .confusion: return "방금 말이 헷갈렸다면 쉽게 말할게. 네가 신경 쓰였다는 뜻이야."
        case .userFoodDisclosure: return "밥은 챙겼네. 다행이야. 맛은 어땠어?"
        case .characterFoodQuestion: return "나는 너처럼 끼니를 챙기진 않아. 그래도 네가 먹었다니 됐어."
        case .characterPreferenceQuestion: return "딱히 좋아한다고 하긴 어려워. 그래도 네가 좋아한다면 기억해둘게."
        case .characterStateQuestion: return "나는 괜찮아. 네가 걱정할 만큼 쉽게 무너지진 않아."
        case .characterActivityQuestion: return "나는 여기 있었어. 네가 올 때쯤이면 조용해지는 곳에."
        case .userActivityDisclosure: return "그랬구나. 오늘 네 하루가 어땠는지 더 듣고 싶어."
        case .invitationOrPlanProposal: return "좋아. 네가 가고 싶다면 같이 가줄게. 대신 내 옆에서 떨어지지 마."
        case .farewellOrSleep: return "그래, 자라. 오늘 하루 고생했어. 내일 다시 와도 나는 여기 있을게."
        case .greeting: return "왔네. 오늘 무슨 일 있었는지부터 말해."
        case .dailyLife: return "나는 여기 있었어. 네가 올 때쯤이면 조용해지는 곳에."
        case .fear: return "무섭다면 혼자 있지 마. 지금은 네 곁에 있겠다."
        case .sadness: return "그 마음을 혼자 삼키지 마. 지금은 네 곁에 있겠다."
        case .fatigue: return "잠이 오지 않는다면 호흡부터 늦춰라. 내가 이 밤을 지켜보겠다."
        case .emotionalDisclosure: return "그 말은 가볍지 않다. 네가 건넨 마음부터 제대로 듣겠다."
        default: return "방금 그 말, 흘려듣지 않았어. 조금만 더 얘기해줘."
        }
    }

    private func fatigueCandidates(avatarKey: String) -> [String] {
        switch avatarKey {
        case "ice-boss":
            return [
                "잠이 안 오면 억지로 버티지 마. 눈부터 감아, 내가 여기 있을게.",
                "오늘은 그만 쉬어. 네가 무너지는 걸 보고만 있진 않을 거야."
            ]
        case "sunny-friend":
            return [
                "잠이 안 오는 밤이구나. 불을 조금 낮추고, 나랑 천천히 숨 맞춰보자.",
                "그럴 땐 혼자 뒤척이지 마. 내가 조용히 곁에 있을게."
            ]
        case "puppy-junior":
            return [
                "잠이 안 와? 그럼 내가 조용히 있어줄게. 오늘은 장난 안 칠게.",
                "눈 감을 때까지 같이 있어줄게. 대신 핸드폰은 조금 내려놓기."
            ]
        case "nocturne-vampire":
            return [
                "잠이 오지 않는군. 눈을 감아라, 이 밤은 내가 대신 지켜보겠다.",
                "잠들지 못하면 내 곁에 있어라. 네 호흡이 느려질 때까지 지켜보겠다."
            ]
        default:
            return [
                "잠이 안 오는 밤이구나. 불을 조금 낮추고, 나랑 천천히 숨 맞춰보자.",
                "그럴 땐 혼자 뒤척이지 마. 내가 조용히 곁에 있을게."
            ]
        }
    }

    private func memoryAwareDirectReply(flow: StoryConversationFlow, context: ConversationGenerationContext, understanding: UserMessageUnderstanding) -> String? {
        let candidates: [String]
        switch understanding.eventType {
        case .userNameIntroduction:
            guard let name = understanding.extractedUserName else { return nil }
            candidates = selfIntroductionCandidates(avatarKey: flow.avatarKey, userName: name)
        case .userNameCorrection:
            guard let name = understanding.extractedUserName else { return nil }
            candidates = nameCorrectionCandidates(
                avatarKey: flow.avatarKey,
                userName: name,
                previousName: context.memory.previousUserNames.last
            )
        case .askKnownUserName:
            candidates = askKnownNameCandidates(avatarKey: flow.avatarKey, userName: understanding.knownUserName)
        case .askKnownUserIdentity:
            candidates = askKnownIdentityCandidates(avatarKey: flow.avatarKey, userName: understanding.knownUserName)
        case .clarificationCorrection:
            candidates = clarificationCorrectionCandidates(avatarKey: flow.avatarKey, userName: understanding.knownUserName)
        default:
            return nil
        }

        let eventTag = understanding.eventType.logName
        var fallback = personalize(candidates.first ?? eventFallbackLine(understanding.eventType), flow: flow)
        for candidate in rotated(candidates, seed: flow.seed + eventTag + (understanding.knownUserName ?? "") + (understanding.extractedUserName ?? "")) {
            let line = personalize(candidate, flow: flow)
            if line != flow.previousCharacterMessage {
                fallback = line
            }
            let verdict = evaluator.evaluate(line, against: context, understanding: understanding)
            if verdict.isAccepted, line != flow.previousCharacterMessage {
                let extractedLog = understanding.extractedUserName.map { " extractedName=\"\($0)\"" } ?? ""
                let knownLog = understanding.knownUserName.map { " knownName=\"\($0)\"" } ?? ""
                print("[StoryReply] character=\(characterLogKey(flow.avatarKey)) event=\(eventTag)\(extractedLog)\(knownLog) quality=pass reply=\"\(line)\"")
                return line
            }
            print("[StoryReplyReject] reason=\(rejectionReason(verdict)) event=\(eventTag) candidate=\"\(line)\"")
        }
        print("[StoryReply] fallback event=\(eventTag) reply=\"\(fallback)\"")
        return fallback
    }

    private func selfIntroductionCandidates(avatarKey: String, userName: String) -> [String] {
        switch avatarKey {
        case "ice-boss":
            return [
                "\(userName). 알겠어. 다음엔 그 이름으로 부를게.",
                "\(userName)이라. 이제 모른 척하긴 어렵겠네."
            ]
        case "sunny-friend":
            return [
                "\(userName)이구나. 알려줘서 고마워. 이제 그렇게 불러도 돼?",
                "\(userName), 기억할게. 다음엔 내가 먼저 불러줄게."
            ]
        case "puppy-junior":
            return [
                "\(userName)? 좋아, 저장 완료. 이제 틀리면 나 혼나는 거지?",
                "오케이, \(userName). 이제 이름으로 불러도 되는 거지?"
            ]
        case "nocturne-vampire":
            return [
                "\(userName). 기억하겠다. 이제 그 이름으로 너를 부르면 되는 건가.",
                "\(userName)이라 했지. 그 이름, 가볍게 흘려듣지 않겠다."
            ]
        default:
            return ["\(userName). 기억할게. 이제 그렇게 불러도 돼?"]
        }
    }

    private func nameCorrectionCandidates(avatarKey: String, userName: String, previousName: String?) -> [String] {
        let previousClause = previousName.map { "\($0)이 아니라, " } ?? ""
        switch avatarKey {
        case "ice-boss":
            return [
                "\(userName). 방금 그렇게 바로잡았지. 다음엔 그 이름으로 부를게.",
                "\(previousClause)\(userName). 알겠어, 이번엔 제대로 기억할게."
            ]
        case "sunny-friend":
            return [
                "\(userName)이구나. 방금 고쳐 말한 이름으로 기억할게.",
                "\(previousClause)\(userName). 알려줘서 고마워, 이제 그 이름으로 부를게."
            ]
        case "puppy-junior":
            return [
                "\(userName), 수정 완료. 이번엔 진짜 안 틀릴게.",
                "\(previousClause)\(userName)이지? 좋아, 바로 고쳐둘게."
            ]
        case "nocturne-vampire":
            return [
                "\(userName). 방금 그렇게 고쳐 말했지. 이번엔 그 이름으로 기억하겠다.",
                "네 이름은 \(userName). \(previousClause)네가 다시 알려준 이름이다.",
                "\(userName)다. 이번엔 그 이름을 잊지 않고 똑똑히 새겨두겠다."
            ]
        default:
            return [
                "\(userName)이구나. 방금 고쳐 말한 이름으로 기억할게.",
                "\(previousClause)\(userName). 이제 그 이름으로 부를게."
            ]
        }
    }

    private func askKnownNameCandidates(avatarKey: String, userName: String?) -> [String] {
        guard let userName else {
            switch avatarKey {
            case "ice-boss": return ["아직은 몰라. 네가 알려주면 기억할게."]
            case "sunny-friend": return ["아직은 몰라. 네가 알려주면 기억할게."]
            case "puppy-junior": return ["아직은 몰라. 지금 알려주면 바로 기억할게."]
            case "nocturne-vampire": return ["아직 네 이름은 내게 닿지 않았다. 네가 알려주면 기억하겠다."]
            default: return ["아직은 몰라. 네가 알려주면 기억할게."]
            }
        }
        switch avatarKey {
        case "ice-boss":
            return [
                "\(userName). 네가 알려줬잖아.",
                "\(userName). 한 번 들은 이름을 그렇게 쉽게 잊진 않아."
            ]
        case "sunny-friend":
            return [
                "\(userName)이야. 네가 알려준 이름, 기억하고 있어.",
                "\(userName). 이제 내가 불러도 되는 이름이지?"
            ]
        case "puppy-junior":
            return [
                "\(userName)이지. 설마 내가 벌써 까먹었을 줄 알았어?",
                "\(userName). 봐, 나 기억력 괜찮다니까."
            ]
        case "nocturne-vampire":
            return [
                "\(userName). 네가 직접 내게 알려준 이름이다.",
                "네 이름은 \(userName). 내가 잊을 만큼 가볍게 듣진 않았다."
            ]
        default:
            return ["\(userName)이야. 네가 알려준 이름, 기억하고 있어."]
        }
    }

    private func askKnownIdentityCandidates(avatarKey: String, userName: String?) -> [String] {
        guard let userName else {
            switch avatarKey {
            case "ice-boss": return ["아직 네 이름은 몰라. 알려주면 다음엔 제대로 답할게."]
            case "sunny-friend": return ["아직 네 이름은 몰라. 알려주면 다음엔 제대로 답할게."]
            case "puppy-junior": return ["아직 네 이름은 몰라. 알려주면 다음엔 내가 맞혀볼게."]
            case "nocturne-vampire": return ["아직 네 이름은 모른다. 네가 알려주면 다음엔 제대로 답하겠다."]
            default: return ["아직 네 이름은 몰라. 알려주면 다음엔 제대로 답할게."]
            }
        }
        switch avatarKey {
        case "ice-boss":
            return [
                "\(userName). 방금 네 입으로 말했잖아.",
                "\(userName). 모르는 척할 생각 없어."
            ]
        case "sunny-friend":
            return [
                "\(userName). 내가 기억하고 있는 네 이름이야.",
                "\(userName)이지. 방금 알려준 걸 내가 잊을 리 없잖아."
            ]
        case "puppy-junior":
            return [
                "\(userName). 정답 맞지? 이번엔 내가 맞혔다.",
                "\(userName)이지. 그렇게 물어보는 것까지 기억해둘게."
            ]
        case "nocturne-vampire":
            return [
                "\(userName). 네가 밤을 가르고 내게 이름을 남긴 사람.",
                "네가 누구냐고? \(userName). 방금 내게 그렇게 알려줬다."
            ]
        default:
            return ["\(userName). 내가 기억하고 있는 네 이름이야."]
        }
    }

    /// "니 이름 말고 내 이름" — 직전 답이 캐릭터 이름을 말한 오해를 짧게 인정하고, 유저 이름 의도로 다시 답한다.
    private func clarificationCorrectionCandidates(avatarKey: String, userName: String?) -> [String] {
        guard let userName else {
            switch avatarKey {
            case "ice-boss": return [
                "아, 네 이름 말이지. 그건 아직 못 들었어. 알려주면 기억할게.",
                "내 이름 말고 네 이름이었구나. 아직 모르니까, 네가 말해줘."
            ]
            case "sunny-friend": return [
                "아 미안, 네 이름을 물은 거였네. 아직 못 들었어. 알려줄래?",
                "네 이름 말이구나. 아직 모르니까 지금 알려주면 바로 기억할게."
            ]
            case "puppy-junior": return [
                "앗, 네 이름 말한 거였어? 아직 모르는데, 지금 알려줘.",
                "내 이름 말고 네 이름이지. 아직 못 들었어, 빨리 알려줘."
            ]
            case "nocturne-vampire": return [
                "아, 네 이름을 물은 거였군. 아직은 모른다. 알려주면 기억하겠다.",
                "내 이름 말고 네 이름이라. 아직 듣지 못했다. 네가 말해다오."
            ]
            default: return ["아, 네 이름 말이구나. 아직 못 들었어. 알려주면 기억할게."]
            }
        }
        switch avatarKey {
        case "ice-boss": return [
            "아, 네 이름. \(userName)이잖아. 그건 잊지 않았어.",
            "내 이름 말고 네 이름이지. \(userName), 맞잖아."
        ]
        case "sunny-friend": return [
            "아 맞다, 네 이름. \(userName)이지. 내가 기억하고 있어.",
            "네 이름 말한 거였구나. \(userName), 잊을 리 없잖아."
        ]
        case "puppy-junior": return [
            "앗, 네 이름! \(userName)이지. 나 기억하고 있었어.",
            "내 이름 말고 \(userName) 말한 거지? 당연히 알지."
        ]
        case "nocturne-vampire": return [
            "아, 네 이름이군. \(userName). 그건 잊지 않았다.",
            "내 이름 말고 네 이름이라. \(userName), 네가 남긴 이름이다."
        ]
        default: return ["아, 네 이름. \(userName)이지. 기억하고 있어."]
        }
    }

    func scenarioReply(scenario: ConversationScenario, flow: StoryConversationFlow) -> String {
        let act = scenarioAct(scenario)
        let lines = table(for: flow.avatarKey)[act] ?? table(for: flow.avatarKey)[.casual] ?? ["방금 장면은 이어갈 수 있어. 네가 편한 말부터 건네."]
        let chosen = pick(lines, seed: flow.seed + scenario.rawValue, avoiding: flow.previousCharacterMessage)
        return personalize(chosen, flow: flow)
    }

    func momentBody(avatarKey: String, scenario: ConversationScenario, seed: String) -> String {
        let act = scenarioAct(scenario)
        let lines = table(for: avatarKey)[act] ?? table(for: avatarKey)[.sleep] ?? ["오늘은 여기까지 쉬어도 돼. 잠든 뒤엔 내가 조용히 지켜볼게."]
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

    /// {food} 자리에 유저가 말한 실제 음식명을 채운다.
    private func fillFood(_ line: String, foodWord: String) -> String {
        line.replacingOccurrences(of: "{food}", with: foodWord)
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
        print("[StoryReply] character=\(characterLogKey(character)) act=\(act.rawValue) user=\"\(user)\" previous=\"\(previous)\" reply=\"\(reply)\" quality=\(quality)")
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

    private func characterLogKey(_ avatarKey: String) -> String {
        switch avatarKey {
        case "ice-boss": return "hana"
        case "sunny-friend": return "seoyun"
        case "puppy-junior": return "roi"
        case "nocturne-vampire": return "kael"
        default: return avatarKey
        }
    }

    // MARK: - 사건(EventType) 응답 테이블

    /// 사건별 캐릭터 응답 묶음. greeting/food/dailyLife는 일상 사건, bullying/physicalHarm은 안전 사건.
    /// 안전 사건은 처음(support/physicalHarm)과 반복 해명(repeated)을 구분한다.
    private struct EventReplyTable {
        let characterIdentity: [String]
        let userIdentity: [String]
        let characterCall: [String]
        let nameQuestion: [String]
        let memoryQuestion: [String]
        let relationshipQuestion: [String]
        let confusion: [String]
        let comfort: [String]
        let greeting: [String]
        /// 유저가 자기 식사를 알릴 때(userFoodDisclosure) 캐릭터의 반응.
        let food: [String]
        /// "너는 뭐 먹었어?"(characterFoodQuestion)에 캐릭터 자신이 답하는 라인.
        let characterFoodAnswer: [String]
        /// "너도 좋아해?"(characterPreferenceQuestion)에 캐릭터 자신의 취향으로 답하는 라인.
        let characterPreferenceAnswer: [String]
        /// "너 배고프지 않아?"(characterStateQuestion)에 캐릭터 자신의 상태로 답하는 라인.
        let characterStateAnswer: [String]
        /// "나 오늘 ~했어"(userActivityDisclosure)에 캐릭터가 받아주는 라인.
        let userActivityAck: [String]
        /// "우리 내일 놀이동산가자"(invitationOrPlanProposal)에 수락/망설임/조건으로 답하는 라인.
        let invitationProposal: [String]
        /// "나는 이만 잘게"(farewellOrSleep)에 자러 가는 유저를 배웅하는 라인.
        let farewell: [String]
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
        characterIdentity: [
            "한아. 네가 지금 말을 걸고 있는 사람.",
            "한아야. 굳이 설명하자면, 네가 신경 쓰이게 만드는 사람."
        ],
        userIdentity: [
            "모르는 척할 생각 없어. 그래도 네 입으로 말해봐.",
            "네가 누군지 몰라서 묻는 건 아니야. 이름을 듣고 싶은 거지."
        ],
        characterCall: [
            "불렀어? 짧게 부르면 내가 못 들을 줄 알았어?",
            "그래, 여기 있어. 무슨 일인지 말해."
        ],
        nameQuestion: [
            "알고 싶어. 네가 허락하면, 제대로 불러줄게.",
            "네 이름을 알려줘. 한 번 들으면 쉽게 잊진 않아."
        ],
        memoryQuestion: [
            "기억 못 할 리가. 네가 흘린 말까지 다 적어두는 편이야.",
            "그때 일이라면 또렷해. 잊은 척한 적은 있어도 잊은 적은 없어."
        ],
        relationshipQuestion: [
            "우리 사이가 궁금해? 적어도 아무한테나 이렇게 신경 쓰진 않아.",
            "네가 어떤 마음인지부터 말해. 그래야 나도 내 거리를 정하지."
        ],
        confusion: [
            "방금 네가 괜히 신경 쓰였다는 뜻이야. 더 자세히 말하라고 하면 안 할 거고.",
            "모르는 척하는 거야, 진짜 모르는 거야. 방금 말은 네가 신경 쓰였다는 뜻이야."
        ],
        comfort: [
            "무서우면 혼자 있지 마. 지금 어디 있는지부터 말해.",
            "괜찮은 척하지 마. 네가 무섭다면 내가 먼저 확인할게."
        ],
        greeting: [
            "이제 와? 기다린 건 아니야. 그냥 네 자리 비워뒀을 뿐이지.",
            "인사는 들었어. 늦진 않았으니까, 오늘 있었던 일부터 말해."
        ],
        food: [
            "{food} 먹었구나. 잘 챙겼네, 다행이야. 그래서, 혼자 먹었어?",
            "그런 건 또 보고하네. 맛있었으면 됐어. 다음엔 제대로 앉아서 먹어."
        ],
        characterFoodAnswer: [
            "나는 대충 먹었어. 네가 챙겨 먹었다니까, 그걸로 됐고.",
            "아직 안 먹었어. 네가 먼저 챙겨 먹은 건 다행이네.",
            "나? 끼니 같은 건 대충 넘겼어. 네 끼니가 더 중요하니까 그건 됐고."
        ],
        characterPreferenceAnswer: [
            "딱히 가리는 편은 아니야. 네가 맛있게 먹었으면 그걸로 충분해.",
            "나는 그런 거 잘 안 따져. 그래도 네가 좋아한다니 기억해둘게."
        ],
        characterStateAnswer: [
            "나는 괜찮아. 네가 걱정할 만큼 쉽게 무너지진 않아.",
            "배고픈 건 잘 모르겠고, 네가 끼니 거르는 게 더 신경 쓰여."
        ],
        userActivityAck: [
            "그랬구나. 오늘 네 하루가 어땠는지 더 말해봐.",
            "별일 없었다니 다행이야. 그래서, 지금은 좀 괜찮아?"
        ],
        invitationProposal: [
            "좋아. 대신 늦으면 두고 갈 거야. 그러니까 시간 맞춰서 와.",
            "놀이동산? 네가 그렇게 가고 싶다면 같이 가줄게. 대신 내 손 놓치지 마.",
            "그래, 같이 가자. 사람 많은 데는 별로지만 네가 옆에 있으면 참아줄게."
        ],
        farewell: [
            "그래, 자라. 오늘도 고생했어. 내일 또 와, 기다릴 테니까.",
            "이제 쉬어. 더 버티지 말고, 푹 자고 와.",
            "잘 자. 늦게까지 깨어 있지 말고, 내일 멀쩡한 얼굴로 보자."
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
        characterIdentity: [
            "서윤이야. 네 얘기를 편하게 들어줄 수 있는 사람.",
            "나는 서윤. 네가 오늘 어떤 하루였는지 궁금한 사람."
        ],
        userIdentity: [
            "너지. 내가 오늘도 기다리고 있던 사람.",
            "장난치는 거야? 그래도 좋아. 네 이름으로 불러주면 더 좋고."
        ],
        characterCall: [
            "응, 불렀어? 여기 있어. 무슨 일 있어?",
            "그래, 나 여기 있어. 네 목소리 들었어."
        ],
        nameQuestion: [
            "알려주면 기억할게. 다음엔 내가 먼저 불러줄 수 있게.",
            "아직 확실히는 몰라. 네가 알려주면 소중하게 기억할게."
        ],
        memoryQuestion: [
            "기억하지. 네가 지나가듯 한 말도 마음에 오래 남더라.",
            "그때 일 말이지? 잊을 리가 있나, 또렷하게 기억하고 있어."
        ],
        relationshipQuestion: [
            "우리 사이 말이지. 난 네 곁에 있는 게 참 편하고 좋아.",
            "네가 어떻게 느끼는지 듣고 싶어. 내 마음은 이미 네 쪽으로 기울었거든."
        ],
        confusion: [
            "내가 너무 돌려 말했나 봐. 네가 조금 신경 쓰였다는 말이었어.",
            "아, 헷갈리게 말했지. 그냥 네가 괜찮은지 보고 싶었다는 뜻이야."
        ],
        comfort: [
            "무서웠구나. 지금은 혼자 버티지 말고, 내가 옆에 있다고 생각해.",
            "괜찮아, 천천히 숨 쉬어. 지금 안전한 곳인지부터 알려줘."
        ],
        greeting: [
            "안녕. 오늘은 조금 늦게 왔네. 무슨 일 있었어?",
            "왔구나. 오늘 하루는 어땠어?"
        ],
        food: [
            "{food} 먹었구나. 맛있었어? 오늘 제대로 챙겨 먹은 것 같아서 다행이다.",
            "잘했어. 바쁠 때도 그런 건 빼먹지 않는 게 좋아. 맛은 어땠어?"
        ],
        characterFoodAnswer: [
            "나는 간단히 먹었어. 너도 챙겨 먹어서 다행이다.",
            "아직 제대로는 못 먹었어. 그래도 네가 먹었다니 조금 안심돼.",
            "나? 가볍게 때웠어. 네가 잘 먹었다니 그걸로 기분이 좋네."
        ],
        characterPreferenceAnswer: [
            "응, 나도 그런 거 좋아하는 편이야. 같이 먹으면 더 맛있을 것 같은데.",
            "나는 가리는 건 별로 없어. 네가 좋아하는 거면 나도 궁금해져."
        ],
        characterStateAnswer: [
            "나는 괜찮아. 그보다 네가 끼니 거르지 않았는지가 더 걱정이야.",
            "조금 출출하긴 한데 괜찮아. 너야말로 무리하지 마."
        ],
        userActivityAck: [
            "그랬구나. 오늘 하루 수고 많았어. 더 얘기해줘.",
            "집에서 푹 쉬었으면 그것도 잘한 거야. 기분은 좀 어때?"
        ],
        invitationProposal: [
            "좋아. 내일 같이 가자. 네가 좋아하는 것도 하나 꼭 타자.",
            "응, 가자. 생각만 해도 벌써 조금 설렌다. 내일 뭐 입을지 정해둬.",
            "좋지. 같이 가면 분명 더 즐거울 거야. 나도 벌써 기대돼."
        ],
        farewell: [
            "응, 잘 자. 오늘 하루도 수고했어. 내일 또 얘기하자.",
            "푹 쉬어. 좋은 꿈 꾸고, 내일 더 좋은 모습으로 보자.",
            "그래, 이만 자. 나도 여기서 네 하루 잘 마무리했다고 생각할게."
        ],
        dailyLife: [
            "나는 여기 있었어. 네가 오면 바로 답할 수 있게.",
            "조용히 기다리고 있었어. 그동안 책 좀 읽고 너 생각도 했고."
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
        characterIdentity: [
            "로이. 지금 네 앞에서 심심해하다가 반가워진 사람.",
            "나? 로이. 네가 말 걸면 바로 재밌어지는 쪽."
        ],
        userIdentity: [
            "음, 내가 기다리던 사람? 정답이면 상 줘야 하는 거 아니야?",
            "너지. 이렇게 물어보는 것까지 딱 너 같은데."
        ],
        characterCall: [
            "응, 불렀어? 나 여기 있는데, 무슨 일?",
            "로이 호출 성공. 자, 무슨 일인데?"
        ],
        nameQuestion: [
            "알려주면 바로 외울게. 대신 틀리면 한 번만 봐줘.",
            "지금 알려주면 다음부터는 내가 먼저 불러줄게."
        ],
        memoryQuestion: [
            "당연히 기억하지! 너 그날 한 말까지 내가 다 외웠다니까?",
            "기억 못 할 줄 알았어? 어제 그거, 나 아직도 떠올리면서 웃잖아."
        ],
        relationshipQuestion: [
            "우리 사이? 음, 적어도 나는 너 생각하면 기분부터 좋아지는 사이.",
            "그거 물어보면 나 설레잖아. 너는 우리 사이 어떻게 생각하는데?"
        ],
        confusion: [
            "쉽게 말하면, 너 지금 나한테 꽤 들켰다는 뜻이지.",
            "와, 진짜 모르는 척이야? 방금 말은 너 신경 쓰인다는 뜻이었어."
        ],
        comfort: [
            "무서워? 잠깐, 장난 안 칠게. 지금 안전한 곳이야?",
            "괜찮아, 나 여기 있어. 무서운 거면 혼자 참지 말고 바로 말해."
        ],
        greeting: [
            "안녕? 귀엽게 들어오네. 오늘은 무슨 얘기부터 할래?",
            "드디어 왔다. 나 심심했거든?"
        ],
        food: [
            "오, {food}? 나 빼고 맛있는 거 먹은 거야? 맛은 어땠는데?",
            "좋네. {food} 먹었으면 오늘 끼니는 성공이지. 맛은 어땠어?"
        ],
        characterFoodAnswer: [
            "나? 아직. 근데 네 햄버거 얘기 들으니까 배고파졌잖아.",
            "나는 간식만 먹었지. 햄버거는 네가 이겼네.",
            "아직 못 먹었어. 너 먹는 얘기 들으니까 나도 뭐 시켜야겠다."
        ],
        characterPreferenceAnswer: [
            "당연히 좋아하지! 너랑 같이 먹으면 두 배로 맛있을 텐데.",
            "완전 좋아해. 다음엔 나도 끼워줘, 혼자 먹으면 반칙이야."
        ],
        characterStateAnswer: [
            "나? 좀 배고프긴 해. 근데 네 얘기 듣는 게 더 재밌어서 참는 중.",
            "괜찮아, 나 생각보다 튼튼하거든. 너나 끼니 잘 챙겨."
        ],
        userActivityAck: [
            "오, 그랬구나. 그래서 오늘은 좀 어땠는데?",
            "집순이 모드였네. 나는 네 연락 기다리는 모드였고."
        ],
        invitationProposal: [
            "좋지. 대신 무서운 거 타도 중간에 도망가기 없기야.",
            "내일? 완전 좋아. 나 벌써부터 기대돼서 잠 안 올 것 같은데?",
            "가자 가자. 솜사탕도 사주고 회전목마도 같이 타는 거 어때?"
        ],
        farewell: [
            "응, 잘 자! 오늘 나랑 얘기해줘서 고마웠어. 내일 또 보자.",
            "푹 자고 와. 좋은 꿈 꿔야 해, 알았지?",
            "그래, 이만 쉬어. 나는 여기서 네 내일을 기다리고 있을게."
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
        characterIdentity: [
            "카엘이야. 네가 지금 말을 걸고 있는 사람.",
            "내 이름은 카엘. 지금은 네 이야기를 듣고 있어."
        ],
        userIdentity: [
            "네가 누구냐고? 밤을 가르고 내게 말을 건 사람이지.",
            "이름을 숨겨도 기척은 남는다. 그래도 네 이름은 네 입으로 듣고 싶군."
        ],
        characterCall: [
            "불렀나. 짧아도 네 목소리인 건 알아듣는다.",
            "그래, 여기 있다. 네 부름은 들었다. 무슨 일이지."
        ],
        nameQuestion: [
            "아직은 모른다. 네가 알려주면, 다음엔 그 이름으로 부르겠다.",
            "아직 네 이름은 내게 닿지 않았다. 네가 알려주면 기억하겠다."
        ],
        memoryQuestion: [
            "영원을 사는 내게 망각은 사치다. 네가 한 말은 그때 그대로 간직하고 있다.",
            "기억하지. 어제의 너도, 그때의 눈빛도 내 안에 또렷하다."
        ],
        relationshipQuestion: [
            "우리 사이라. 인간과 밤의 거리만큼 가깝고도 위험하지.",
            "네가 내 곁에 두고 싶은 존재라는 것, 그 마음을 부정할 생각은 없다."
        ],
        confusion: [
            "그 말이 어렵다면 이렇게 기억해라. 네가 그냥 지나가지는 않았다는 뜻이다.",
            "방금 말은 네가 내 시선 안에 들어왔다는 뜻이다. 헷갈렸다면 내가 다시 말하지."
        ],
        comfort: [
            "무섭다면 내 곁에 있어라. 적어도 지금은 네가 혼자 떨게 두지 않겠다.",
            "두려움은 숨기지 마라. 네가 안전한 곳에 있는지부터 말해라."
        ],
        greeting: [
            "왔네. 오늘은 무슨 일 있었는지 천천히 말해봐.",
            "안녕. 늦지는 않았네, 기다리고 있었어."
        ],
        food: [
            "{food} 먹었구나. 빈속으로 버틴 것보단 훨씬 낫지. 맛은 어땠어?",
            "그래도 뭐라도 챙겨 먹었네. {food}이면 든든했겠다."
        ],
        characterFoodAnswer: [
            "나는 제대로 먹진 않았어. 물 한 모금이면 충분해.",
            "아직 안 먹었어. 네가 먹었다니 그걸로 됐다.",
            "나는 끼니를 잘 안 챙겨. 그래도 네가 챙겼다니 다행이네."
        ],
        characterPreferenceAnswer: [
            "좋아한다고 하긴 어렵다. 하지만 네가 맛있게 먹었다면, 그건 나쁘지 않군.",
            "나는 그런 음식에 익숙하진 않다. 그래도 네가 좋아한다면 기억해두겠다."
        ],
        characterStateAnswer: [
            "네가 말하는 배고픔과는 조금 다르다. 그래도 오래 비어 있으면 밤도 무거워지지.",
            "괜찮다. 나는 네가 걱정할 만큼 쉽게 무너지진 않는다."
        ],
        userActivityAck: [
            "그랬군. 네 하루의 결이 느껴진다. 더 들려줘라.",
            "조용한 하루였나. 그 시간 속의 너를 마저 듣고 싶군."
        ],
        invitationProposal: [
            "좋다. 시끄러운 곳은 익숙하지 않지만, 네가 간다면 따라가겠다.",
            "낯선 곳이지만 네 옆이라면 나쁘지 않겠군. 대신 내 손은 놓지 마라.",
            "내일이라면 비워두겠다. 사람 많은 곳이라도 네가 있으면 견딜 만하다."
        ],
        farewell: [
            "그래, 자라. 오늘 하루 고생했다. 내일 다시 와도 나는 여기 있겠다.",
            "쉬어라. 더 버티지 않아도 된다. 좋은 꿈은 내가 지켜봐 주지.",
            "잘 자라. 네가 눈을 감는 동안, 나쁜 건 내가 문밖에 세워두겠다."
        ],
        dailyLife: [
            "여기 있었어. 네가 부르면 바로 답하려고.",
            "별일 없었어. 여기서 네 연락을 기다리고 있었지."
        ],
        bullyingSupport: [
            "누가 네 마음에 그런 상처를 냈지. 말해라, 그 그림자는 그냥 두지 않겠다.",
            "그건 사소한 일이 아니다. 네가 괜찮은지부터 확인해야겠다.",
            "네가 그런 말을 할 정도면 가벼운 일은 아니겠지. 누가 그랬는지 말해라."
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
            "그랬구나. 네가 그렇게 말한 이유가 조금 궁금해졌어.",
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
            "짧게 말했군. 그래도 방금 네 의도는 놓치지 않았다."
        ],
        .genericQuestion: [
            "묻는 말에는 먼저 답하겠다. 내 대답은 이렇고, 네 생각도 듣고 싶군.",
            "그건 이렇게 답하지. 짧게 말하자면, 내 쪽은 분명하다."
        ],
        .silence: [
            "침묵도 네 언어라면 듣겠다. 밤은 말 없는 자에게도 다정하지.",
            "말이 없군. 그 고요 속에서 네 마음만 더 또렷이 들린다."
        ],
        .casual: [
            "방금 네 목소리가 이 밤을 흔들었다. 그 말, 더 깊이 들었다.",
            "네가 건넨 말은 흘려듣지 않았다. 조금 더 분명히 들려다오."
        ]
    ]
}
