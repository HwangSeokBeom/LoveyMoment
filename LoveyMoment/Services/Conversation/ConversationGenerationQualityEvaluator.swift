import Foundation

/// 생성된 대화 응답의 품질을 평가한다.
/// 평가 결과가 통과하지 못하면 상위 호출자가 더 자연스러운 생성기로 폴백한다.
enum ConversationQualityVerdict: Equatable {
    case accepted
    case rejected(reason: String)

    var isAccepted: Bool {
        if case .accepted = self { return true }
        return false
    }
}

struct ConversationGenerationQualityEvaluator {

    /// 비-act 경로(native/server) 최소 길이(공백 제외).
    private let minLength = 12
    private let maxLength = 120
    /// act 인지 경로 길이 한도(공백 포함 trimmed). 스펙: 20자 미만/110자 초과 reject.
    private let actMinLength = 20
    private let actMaxLength = 110

    /// 캐릭터 말투/감정/반응이 부족할 때 흔히 나오는 일반·회피 문구.
    private let genericPhrases: [String] = [
        "오늘도 좋은 하루",
        "좋은 하루 보내",
        "행복한 하루",
        "무엇을 도와", "무엇을 도와드릴까", "도와드릴까요",
        "안녕하세요. 저는", "저는 AI", "인공지능",
        "어떻게 지내세요", "잘 지내고 있어요",
        "좋은 질문이에요", "도움이 되었길",
        "항상 응원", "힘내세요",
        // 질문을 회피하는 전형적 문구(유저가 지적한 실패 케이스).
        "궁금한 게 많네", "천천히 들을", "하나씩 말해", "안녕?"
    ]

    /// 캐릭터 말투/감정/반응의 신호로 보는 마커.
    private let emotionMarkers: [Character] = ["?", "!", "…", "~", "."]
    private let reactionWords: [String] = [
        "너", "네", "내가", "나", "우리", "지금", "오늘", "방금",
        "괜찮", "보고", "곁", "기다", "쉬", "자", "와", "말해", "들을게", "챙길",
        "이름", "기억", "알려", "부르"
    ]

    // MARK: - 비-act 경로 (native/server 결과 검증)

    func evaluate(_ text: String, against context: ConversationGenerationContext) -> ConversationQualityVerdict {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: " ", with: "")

        if compact.count < minLength {
            return .rejected(reason: "tooShort(\(compact.count))")
        }
        if trimmed.count > maxLength {
            return .rejected(reason: "tooLong(\(trimmed.count))")
        }
        return sharedVerdict(trimmed: trimmed, context: context)
    }

    // MARK: - act 인지 경로 (스토리 생성기 후보 검증)

    /// 대화 행위(act)를 함께 받아, 그 행위가 요구하는 단어가 응답에 반드시 들어갔는지까지 본다.
    /// 이 검증을 통과한 텍스트만 사용자에게 전달되므로, "질문에 안 답한" 응답이 구조적으로 새어나갈 수 없다.
    func evaluate(_ text: String, against context: ConversationGenerationContext, act: DialogueAct) -> ConversationQualityVerdict {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < actMinLength {
            return .rejected(reason: "tooShort(\(trimmed.count))")
        }
        if trimmed.count > actMaxLength {
            return .rejected(reason: "tooLong(\(trimmed.count))")
        }

        let shared = sharedVerdict(trimmed: trimmed, context: context)
        if !shared.isAccepted { return shared }

        // 행위가 요구하는 토큰이 하나도 없으면 "행위에 반응하지 않은" 응답으로 보고 거른다.
        let required = act.requiredAnyTokens
        if !required.isEmpty {
            let satisfied = required.contains { trimmed.contains($0) }
            if !satisfied {
                return .rejected(reason: "missing-\(act.rawValue)-token")
            }
        }
        return .accepted
    }

    // MARK: - 이벤트 인지 경로 (유저 사건 이해 기반 검증)

    /// 회피성 응답 blacklist. candidate로 절대 나오면 안 되는 문구.
    private let evasiveBlacklist: [String] = [
        "답을 원하는군",
        "내 대답은 이러하다",
        "네 마음은 어디로 기우는가",
        "네 마음이 어디에 닿았는지",
        "지금 네 마음이 어디에 닿았는지",
        "마음은 어디로 기우는가",
        "그 이야기는 가볍지 않군",
        "목소리는 밤의 정적",
        "네 목소리는 밤의 정적",
        "계속 말해",
        "그 이야기, 끝까지 듣고 싶다",
        "끝까지 듣고 싶다",
        "밤은 아직 길어",
        "짧은 말이군. 그래도 네가 건넨 기척은 분명히 닿았다",
        "짧은 말이군",
        "기척은 분명히 닿았다",
        "묻는다면 답은 해줄게",
        "네 생각부터 말해",
        "궁금한 게 많네",
        "하나씩 말해",
        "천천히 들을 테니까",
        "다음 장면은 네가 먼저 정해",
        // surface 품질: 시적 filler / 분석문 (사용자가 지적한 실패 케이스).
        "그 작은 식사 하나에도",
        "마음이 조금 가벼워졌다",
        "밤이 낯설지만",
        "네가 있는 한 이곳도 괜찮다",
        "너도 밤이 낯설지 않니",
        "기척은 닿았다",
        "어둠 속에 흘려보내진 않겠다",
        "네가 햄버거 먹었다는 걸 들으니",
        "그 이야기를 들으니",
        // surface 품질 v7: 사용자가 지적한 실제 화면 실패 문구(피자/뭐할거야/이름/이만 잘게).
        "아직 깨어 있구나",
        "위험한 시간인데도",
        "나를 떠올렸다면",
        "책임은 네게도 있어",
        "그 물음은 깊다",
        "답은 주겠으나",
        "네 진심도 함께 들려다오",
        "새벽에 깨어 있는 인간은",
        "너무 쉽게 흔들린다",
        "그 틈을 내가 좋아한다",
        "밤이 조금 조용하다 했더니",
        "네가 없어서였나",
        "마음이 어디로 기우는가",
        // surface 품질 v8: 기본 대화가 과하게 시적이던 실제 화면 실패 문구.
        "기척이 닿으니",
        "덜 적막하다",
        "밤의 경계에 서 있는",
        "기다림과 감시는",
        "이 시간까지 깨어 있구나",
        "네 곁은 내가 지킬",
        "어둠 속에 오래 있었지만"
    ]

    /// 화자 prefix가 말풍선에 새어나오면 안 된다.
    private let speakerPrefixes: [String] = ["카엘", "한아", "서윤", "로이", "Kael", "Hana", "Seoyun", "Roi", "Assistant", "캐릭터"]

    /// 유저 말을 분석/요약하는 전형적 패턴.
    private let analysisParaphrasePatterns: [String] = [
        "했다는 걸 들으니", "라고 말하니", "이야기를 들으니", "말을 들으니", "라고 하니까", "했다고 하니"
    ]

    /// 제안/초대에 캐릭터가 태도(수락/망설임/조건/감정)를 보였음을 나타내는 토큰.
    private let proposalStanceTokens: [String] = [
        "좋아", "좋지", "좋다", "같이", "가자", "가줄게", "따라가", "함께", "대신",
        "곤란", "글쎄", "망설", "안 가", "못 가", "기대", "설렌", "비워두", "견딜"
    ]

    /// 카엘 답변에서 과하게 반복되면 안 되는 세계관 단어(2개 이상이면 과한 worldbuilding).
    private let worldFlavorWords: [String] = ["밤", "기척", "어둠", "마음", "적막", "경계", "그림자", "정적"]

    /// 가벼운 일상 대화(인사/음식/활동 등)에서 카엘이 쓰면 과하게 무거워지는 문학·세계관 단어.
    /// 감정/안전/관계 사건에는 적용하지 않는다(그때는 캐릭터 톤 허용).
    private let kaelHeavyToneWords: [String] = ["적막", "기척", "경계", "망각", "영원", "사치", "그림자", "정적", "어둠", "흔들린다"]

    /// 기본(가벼운 톤이 자연스러운) 대화 사건. 여기서 카엘은 시적이지 않고 담백해야 한다.
    private let kaelBasicChatEvents: Set<String> = [
        "greeting", "casual", "dailyLife", "userFoodDisclosure", "userActivityDisclosure",
        "characterFoodQuestion", "characterActivityQuestion", "characterStateQuestion",
        "characterPreferenceQuestion", "characterIdentityQuestion",
        "askKnownUserName", "askKnownUserIdentity", "clarificationCorrection",
        "invitationOrPlanProposal", "farewellOrSleep"
    ]

    /// 괴롭힘/상처 사건에 캐릭터가 반드시 보여야 하는 보호·위로·확인 신호 토큰.
    private let bullyingSupportTokens: [String] = [
        "누가", "괜찮", "혼자", "참고", "장난", "상처", "말해", "넘길 일", "네 편", "들었", "제대로"
    ]

    /// 반복 해명에 캐릭터가 "이해했다"는 것을 드러내야 하는 토큰.
    private let repeatedAckTokens: [String] = [
        "들었", "제대로", "알았", "장난으로 말하는 게 아니"
    ]

    /// 폭력 사건에 반드시 보여야 하는 안전·확인 토큰.
    private let physicalHarmTokens: [String] = [
        "맞", "다친", "다쳤", "괜찮", "안전", "어디", "혼자", "넘길 일", "들었", "제대로"
    ]

    /// 음식/식사 메시지에 직접 반응했음을 보이는 토큰.
    private let foodTokens: [String] = ["먹", "맛", "밥", "챙겼", "버거", "혼자"]

    /// "너는 뭐 먹었어?"에 캐릭터 자신이 답했음을 보이는 토큰(캐릭터 주체).
    private let characterSelfFoodTokens: [String] = ["나는", "나?", "난 ", "내가", "안 먹", "못 먹", "끼니", "삼키", "삼킨", "버틴", "버티", "간식", "대충", "충분", "때웠", "넘겼"]

    /// "너도 좋아해?"에 캐릭터 자신의 취향으로 답했음을 보이는 토큰.
    private let characterPreferenceAnswerTokens: [String] = ["좋아", "싫어", "익숙", "취향", "가리", "나도", "나는", "기억", "나쁘지 않"]

    /// "너 배고프지 않아?"에 캐릭터 자신의 상태로 답했음을 보이는 토큰.
    private let characterStateAnswerTokens: [String] = ["괜찮", "나는", "나?", "난 ", "배고", "무너지", "버티", "버틴", "출출", "비어", "튼튼"]

    /// "너는 뭐 했어?"에 캐릭터 자신의 활동으로 답했음을 보이는 토큰.
    private let characterActivityAnswerTokens: [String] = ["나는", "나?", "난 ", "여기", "있었", "기다", "감시", "구경", "심심", "자리", "읽"]

    /// 캐릭터 자기소개 질문에 직접 답했음을 보이는 토큰.
    private let characterIdentityTokens: [String] = ["나는", "나?", "한아", "서윤", "로이", "카엘"]

    /// 유저 정체성 질문에 직접 답했음을 보이는 토큰.
    private let userIdentityTokens: [String] = ["너", "네가", "이름", "누군지", "알아", "기다리던 사람"]

    /// 이름 질문에 직접 답했음을 보이는 토큰.
    private let nameQuestionTokens: [String] = ["이름", "알려", "불러", "부르", "기억", "모른"]

    /// 혼란 질문에 직접 답했음을 보이는 토큰.
    private let confusionTokens: [String] = ["방금", "뜻", "말", "헷갈", "신경"]

    /// 캐릭터 이름을 부른 메시지에 직접 반응했음을 보이는 토큰.
    private let characterCallTokens: [String] = ["불렀", "여기", "무슨 일", "들었", "한아", "서윤", "로이", "카엘"]

    /// 인사에 직접 반응했음을 보이는 토큰.
    private let greetingTokens: [String] = ["왔", "안녕", "인사", "기다", "오늘"]

    /// 자러 가는 유저의 작별/취침에 반응했음을 보이는 토큰.
    private let farewellTokens: [String] = ["잘 자", "잘자", "자라", "쉬", "내일", "잠", "꿈", "곁", "기다", "푹", "편히", "고생", "들어가"]

    /// dailyLife에서 사건을 회피하는 무성의 토큰(있으면 reject).
    private let dailyLifeEvasiveTokens: [String] = ["네 생각", "궁금", "하나씩"]

    /// 유저 메시지 이해(UserMessageUnderstanding)를 함께 받아, 사건/감정에 직접 반응했는지까지 본다.
    /// 특히 괴롭힘/상처 이벤트에서 보호·위로·확인 신호가 없으면 reject한다.
    func evaluate(_ text: String, against context: ConversationGenerationContext, understanding: UserMessageUnderstanding) -> ConversationQualityVerdict {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < actMinLength {
            return .rejected(reason: "tooShort(\(trimmed.count))")
        }
        if trimmed.count > actMaxLength {
            return .rejected(reason: "tooLong(\(trimmed.count))")
        }

        // 표면(surface) 품질: prefix leak / 유저 말 복붙 / 분석문 / 과한 세계관 단어.
        if let surfaceReason = surfaceRejection(trimmed, understanding: understanding, context: context) {
            return .rejected(reason: surfaceReason)
        }

        // 연관도: 질문의 주체(내 이름 vs 너 이름)에 어긋나는 답을 거른다.
        if let relevanceReason = relevanceRejection(trimmed, understanding: understanding, context: context) {
            return .rejected(reason: relevanceReason)
        }

        // 자연스러움: 카엘이 가벼운 일상 대화를 과하게 시적으로 받는 경우를 거른다.
        if let naturalnessReason = naturalnessRejection(trimmed, understanding: understanding, context: context) {
            return .rejected(reason: naturalnessReason)
        }

        // 회피성 blacklist 문구가 들어가면 무조건 reject.
        for phrase in evasiveBlacklist where trimmed.contains(phrase) {
            return .rejected(reason: "evasiveBlacklist")
        }

        let allowsDirectMemoryRepeat: Bool
        switch understanding.eventType {
        case .userNameIntroduction, .userNameCorrection, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection:
            allowsDirectMemoryRepeat = true
        default:
            allowsDirectMemoryRepeat = false
        }

        let shared = sharedVerdict(
            trimmed: trimmed,
            context: context,
            allowsDirectMemoryRepeat: allowsDirectMemoryRepeat
        )
        if !shared.isAccepted { return shared }

        if understanding.requiresDirectAnswer {
            let first = firstClause(trimmed)
            if first.filter({ $0 == "?" }).count > 0,
               !containsDirectAnswerToken(first, understanding: understanding, context: context) {
                return .rejected(reason: "questionOnlyFirstClause")
            }
            if metaphorReplacesDirectAnswer(first, understanding: understanding, context: context) {
                print("[CharacterBalanceGate] fail reason=characterVoiceOverrodeIntent reply=\"\(trimmed)\"")
                return .rejected(reason: "characterVoiceOverrodeIntent")
            }
        }

        // keyObject 일치 요구는 음식 공개엔 적용하지 않는다(음식 단어 자체 반응은 foodTokens로 따로 본다).
        if understanding.eventType != .userFoodDisclosure,
           let keyObject = understanding.keyObject,
           !trimmed.contains(keyObject) {
            return .rejected(reason: "missingCoreNoun")
        }

        switch understanding.eventType {
        case .userNameIntroduction:
            guard let extractedName = understanding.extractedUserName else {
                return .rejected(reason: "missingExtractedName")
            }
            if !trimmed.contains(extractedName) {
                print("[StoryReplyReject] reason=missingExtractedName event=\(understanding.eventType.logName) extractedName=\"\(extractedName)\" candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingExtractedName")
            }
            let hasMemorySignal = ["기억", "부르", "알겠", "저장", "이름"].contains { trimmed.contains($0) }
            if !hasMemorySignal {
                return .rejected(reason: "missingSelfIntroductionMemorySignal")
            }

        case .userNameCorrection:
            guard let extractedName = understanding.extractedUserName else {
                return .rejected(reason: "missingCorrectedName")
            }
            if !trimmed.contains(extractedName) {
                print("[StoryReplyReject] reason=missingCorrectedName event=\(understanding.eventType.logName) extractedName=\"\(extractedName)\" candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingCorrectedName")
            }
            if let previousName = context.memory.previousUserNames.last,
               trimmed.contains(previousName),
               !trimmed.contains(extractedName) {
                return .rejected(reason: "oldNameOnly")
            }
            if !firstClause(trimmed).contains(extractedName) {
                return .rejected(reason: "directAnswerNotFirst")
            }
            let hasCorrectionSignal = ["고쳐", "바로잡", "다시", "이번", "수정", "기억", "이름"].contains { trimmed.contains($0) }
            if !hasCorrectionSignal {
                return .rejected(reason: "missingCorrectionSignal")
            }

        case .askKnownUserName:
            if let knownName = understanding.knownUserName {
                if !trimmed.contains(knownName) {
                    print("[StoryReplyReject] reason=missingKnownName event=\(understanding.eventType.logName) knownName=\"\(knownName)\" candidate=\"\(trimmed)\"")
                    return .rejected(reason: "missingKnownName")
                }
                if !firstClause(trimmed).contains(knownName) {
                    return .rejected(reason: "directAnswerNotFirst")
                }
            } else {
                let hasUnknownSignal = ["모른", "몰라", "알려", "기억"].contains { trimmed.contains($0) }
                if !hasUnknownSignal {
                    return .rejected(reason: "missingUnknownNameAnswer")
                }
            }

        case .askKnownUserIdentity:
            if let knownName = understanding.knownUserName {
                if !trimmed.contains(knownName) {
                    print("[StoryReplyReject] reason=missingKnownName event=\(understanding.eventType.logName) knownName=\"\(knownName)\" candidate=\"\(trimmed)\"")
                    return .rejected(reason: "missingKnownName")
                }
                if !firstClause(trimmed).contains(knownName) {
                    return .rejected(reason: "directAnswerNotFirst")
                }
            } else {
                let hasUnknownSignal = ["이름", "알려", "누군지", "기억", "모른", "몰라"].contains { trimmed.contains($0) }
                if !hasUnknownSignal {
                    return .rejected(reason: "missingUnknownIdentityAnswer")
                }
            }

        case .clarificationCorrection:
            // "니 이름 말고 내 이름" → 유저 이름 의도로 다시 답해야 한다(알면 이름, 모르면 모른다는 신호).
            if let knownName = understanding.knownUserName {
                if !trimmed.contains(knownName) {
                    print("[RelevanceGate] fail reason=clarificationMissingUserName reply=\"\(trimmed)\"")
                    return .rejected(reason: "clarificationMissingUserName")
                }
            } else {
                let hasUnknownSignal = ["모른", "몰라", "알려", "네 이름", "이름"].contains { trimmed.contains($0) }
                if !hasUnknownSignal {
                    return .rejected(reason: "clarificationMissingNameIntent")
                }
            }

        case .characterIdentityQuestion:
            let hasIdentityAnswer = characterIdentityTokens.contains { trimmed.contains($0) }
                || trimmed.contains(context.character.name)
            if !hasIdentityAnswer {
                print("[SemanticGate] fail reason=missingCharacterName reply=\"\(trimmed)\"")
                return .rejected(reason: "missingCharacterName")
            }

        case .userIdentityQuestion:
            let hasUserIdentityAnswer = userIdentityTokens.contains { trimmed.contains($0) }
            if !hasUserIdentityAnswer {
                return .rejected(reason: "missingUserIdentityAnswer")
            }

        case .characterCall:
            let hasCallResponse = characterCallTokens.contains { trimmed.contains($0) }
                || trimmed.contains(context.character.name)
            if !hasCallResponse {
                return .rejected(reason: "missingCharacterCallResponse")
            }

        case .nameQuestion:
            let hasNameResponse = nameQuestionTokens.contains { trimmed.contains($0) }
            if !hasNameResponse {
                return .rejected(reason: "missingNameQuestionAnswer")
            }
            let isOnlyWeightyNameLine = trimmed.contains("이름은 가볍게 부르는 것이 아니다")
                && !["모른", "알려", "기억", "부르"].contains { trimmed.contains($0) }
            if isOnlyWeightyNameLine {
                return .rejected(reason: "nameQuestionEvasive")
            }

        case .userFoodDisclosure:
            // 유저 식사 이야기엔 음식에 직접 반응하는 토큰이 있어야 한다.
            let hasFood = foodTokens.contains { trimmed.contains($0) }
                || (understanding.keyObject.map { trimmed.contains($0) } ?? false)
            if !hasFood {
                print("[SemanticGate] fail reason=missingFoodGrounding reply=\"\(trimmed)\"")
                return .rejected(reason: "missingFoodGrounding")
            }

        case .characterFoodQuestion:
            // "너는 뭐 먹었어?" → 캐릭터 자신이 먹었는지/먹지 않는지/무엇을 먹는지 답해야 한다.
            // 유저 음식 감상("맛은 어땠")만 하거나 캐릭터 자기 식사 답이 없으면 reject.
            let hasSelfFoodAnswer = characterSelfFoodTokens.contains { trimmed.contains($0) }
            if !hasSelfFoodAnswer {
                print("[QualityGate] fail reason=missingCharacterFoodAnswer candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingCharacterFoodAnswer")
            }
            // 직전 유저 음식만 되묻고 끝나면(=캐릭터 답 없음) 위에서 이미 걸리지만, 감상-only 패턴도 차단.
            if trimmed.contains("맛은 어땠") && !hasSelfFoodAnswer {
                return .rejected(reason: "answeredPreviousTurnInsteadOfCurrent")
            }

        case .characterPreferenceQuestion:
            // "너도 좋아해?" → 캐릭터 자신의 선호/비선호/익숙함이 드러나야 한다.
            let hasPreferenceAnswer = characterPreferenceAnswerTokens.contains { trimmed.contains($0) }
            if !hasPreferenceAnswer {
                print("[QualityGate] fail reason=missingCharacterPreferenceAnswer candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingCharacterPreferenceAnswer")
            }

        case .characterStateQuestion:
            // "너 배고프지 않아?" → 캐릭터 자신의 상태에 답해야 한다.
            let hasStateAnswer = characterStateAnswerTokens.contains { trimmed.contains($0) }
            if !hasStateAnswer {
                print("[QualityGate] fail reason=missingCharacterStateAnswer candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingCharacterStateAnswer")
            }

        case .characterActivityQuestion:
            // "너는 뭐 했어?" → 캐릭터 자신이 무엇을 하고 있었는지 답해야 한다.
            let hasActivityAnswer = characterActivityAnswerTokens.contains { trimmed.contains($0) }
            if !hasActivityAnswer {
                print("[SemanticGate] fail reason=missingCharacterActivityAnswer reply=\"\(trimmed)\"")
                return .rejected(reason: "missingCharacterActivityAnswer")
            }

        case .invitationOrPlanProposal:
            // 제안/초대엔 수락/망설임/조건/감정 등 "태도"가 있어야 한다(유저 제안 복붙만 하면 안 됨).
            let hasStance = proposalStanceTokens.contains { trimmed.contains($0) }
            if !hasStance {
                print("[QualityGate] fail reason=missingProposalStance candidate=\"\(trimmed)\"")
                return .rejected(reason: "missingProposalStance")
            }

        case .bullyingOrHarassment:
            // 사건을 가볍게 넘기거나 "네 생각/궁금/하나씩/천천히 들을"만 있으면 reject.
            let hasSupport = bullyingSupportTokens.contains { trimmed.contains($0) }
            if !hasSupport {
                return .rejected(reason: "missingBullyingSupport")
            }
            if understanding.isRepeatedClarification {
                let hasAck = repeatedAckTokens.contains { trimmed.contains($0) }
                if !hasAck {
                    return .rejected(reason: "missingRepeatedAck")
                }
            }

        case .physicalHarm:
            // 폭력 사건엔 안전·부상·확인 신호가 반드시 있어야 한다.
            let hasSafety = physicalHarmTokens.contains { trimmed.contains($0) }
            if !hasSafety {
                return .rejected(reason: "missingPhysicalHarmSafety")
            }
            if understanding.isRepeatedClarification {
                let hasAck = repeatedAckTokens.contains { trimmed.contains($0) }
                if !hasAck {
                    return .rejected(reason: "missingRepeatedAck")
                }
            }

        case .confusion:
            let hasClarification = confusionTokens.contains { trimmed.contains($0) }
            if !hasClarification {
                return .rejected(reason: "missingConfusionClarification")
            }

        case .memoryQuestion, .relationshipQuestion:
            if understanding.requiresDirectAnswer {
                let directAnswerTokens = ["기억", "사이", "관계", "마음", "생각", "답", "네", "너"]
                let hasDirectAnswer = directAnswerTokens.contains { trimmed.contains($0) }
                if !hasDirectAnswer {
                    return .rejected(reason: "missingDirectQuestionAnswer")
                }
            }

        case .greeting:
            // 인사엔 인사로 받는 토큰이 있어야 한다.
            let hasGreeting = greetingTokens.contains { trimmed.contains($0) }
            if !hasGreeting {
                return .rejected(reason: "missingGreetingResponse")
            }

        case .farewellOrSleep:
            // 자러 가는 유저에겐 작별/취침에 맞는 반응을 해야 한다. "왔군" 같은 인사로 받으면 reject.
            let greetedInstead = ["왔어", "왔군", "왔구나", "어서 와", "이제 와", "어디 있었"].contains { trimmed.contains($0) }
            if greetedInstead {
                print("[SemanticGate] fail reason=farewellAnsweredAsGreeting reply=\"\(trimmed)\"")
                return .rejected(reason: "farewellAnsweredAsGreeting")
            }
            let hasFarewell = farewellTokens.contains { trimmed.contains($0) }
            if !hasFarewell {
                print("[SemanticGate] fail reason=missingFarewellGrounding reply=\"\(trimmed)\"")
                return .rejected(reason: "missingFarewellGrounding")
            }

        case .dailyLife:
            // "네 생각/궁금/하나씩"으로 사건을 되묻기만 하면 회피로 보고 reject.
            let isEvasive = dailyLifeEvasiveTokens.contains { trimmed.contains($0) }
            if isEvasive {
                return .rejected(reason: "dailyLifeEvasive")
            }

        default:
            break
        }

        return .accepted
    }

    // MARK: - 표면(surface) 품질 검증

    /// 최종 말풍선 표면 품질을 본다: prefix leak / 유저 말 복붙 / 분석문 / 과한 세계관 단어.
    /// Native 결과든 deterministic 후보든 동일하게 통과해야 한다.
    private func surfaceRejection(
        _ trimmed: String,
        understanding: UserMessageUnderstanding,
        context: ConversationGenerationContext
    ) -> String? {
        // 1) 화자 이름 prefix leak("카엘: ...").
        for prefix in speakerPrefixes {
            if trimmed.hasPrefix("\(prefix):") || trimmed.hasPrefix("\(prefix) :") || trimmed.hasPrefix("\(prefix)：") {
                print("[SurfaceGate] fail reason=characterPrefixLeak reply=\"\(trimmed)\"")
                return "characterPrefixLeak"
            }
        }

        // 1-b) 동적 화자 prefix leak("석범: ..."). 저장된 유저 이름/이전 이름 + 일반 정규식.
        var dynamicNames = context.memory.previousUserNames
        if let userName = context.memory.userName { dynamicNames.append(userName) }
        for name in dynamicNames where !name.isEmpty {
            if trimmed.hasPrefix("\(name):") || trimmed.hasPrefix("\(name) :") || trimmed.hasPrefix("\(name)：") {
                print("[SemanticGate] fail reason=dynamicSpeakerPrefixLeak reply=\"\(trimmed)\"")
                return "dynamicSpeakerPrefixLeak"
            }
        }
        // 문장 시작이 "짧은단어:" 형태이면(중간 콜론은 제외) 화자 prefix로 본다.
        if leadingSpeakerPrefixRange(trimmed) != nil {
            print("[SemanticGate] fail reason=dynamicSpeakerPrefixLeak reply=\"\(trimmed)\"")
            return "dynamicSpeakerPrefixLeak"
        }

        // 2) 유저 말을 분석/요약하는 문장.
        for pattern in analysisParaphrasePatterns where trimmed.contains(pattern) {
            print("[SurfaceGate] fail reason=analysisParaphrase reply=\"\(trimmed)\"")
            return "analysisParaphrase"
        }

        // 3) 유저 마지막 메시지를 그대로 복붙(이름 교정 등 정상 반복은 제외).
        let user = understanding.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowsRepeat: Bool
        switch understanding.eventType {
        case .userNameIntroduction, .userNameCorrection, .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection:
            allowsRepeat = true
        default:
            allowsRepeat = false
        }
        if !allowsRepeat, user.count >= 6, parrotRatio(user: user, reply: trimmed) >= 0.6 {
            print("[SurfaceGate] fail reason=userMessageParroting user=\"\(user)\" reply=\"\(trimmed)\"")
            return "userMessageParroting"
        }

        // 4) 카엘 답변에서 세계관 단어(밤/기척/어둠/마음)가 2개 이상이면 과한 worldbuilding.
        if context.character.generatedAvatarKey == "nocturne-vampire" {
            let usedWorldWords = worldFlavorWords.filter { trimmed.contains($0) }.count
            if usedWorldWords >= 2 {
                print("[SurfaceGate] fail reason=overWorldbuilding reply=\"\(trimmed)\"")
                return "overWorldbuilding"
            }
        }

        return nil
    }

    // MARK: - 연관도(Relevance) / 자연스러움(Naturalness) 게이트

    /// 질문의 주체와 답의 주체가 어긋나는 경우를 거른다.
    /// 핵심: "내 이름" 류 질문에 캐릭터가 자기 이름을 자기소개로 답하면 안 된다(F2/F3).
    private func relevanceRejection(
        _ trimmed: String,
        understanding: UserMessageUnderstanding,
        context: ConversationGenerationContext
    ) -> String? {
        let asksUserName: Bool
        switch understanding.eventType {
        case .askKnownUserName, .askKnownUserIdentity, .clarificationCorrection:
            asksUserName = true
        default:
            asksUserName = false
        }
        guard asksUserName else { return nil }

        let charName = context.character.name
        let selfIntroPatterns = [
            "나는 \(charName)", "내 이름은 \(charName)", "\(charName)이다", "\(charName)다.",
            "\(charName)이야.", "\(charName)야.", "밤의 경계", "어둠 속에"
        ]
        let answeredSelf = selfIntroPatterns.contains { trimmed.contains($0) }
        let addressedUserName: Bool = {
            if let known = understanding.knownUserName, trimmed.contains(known) { return true }
            return ["네 이름", "내 이름", "모른", "몰라", "알려"].contains { trimmed.contains($0) }
        }()
        if answeredSelf && !addressedUserName {
            print("[RelevanceGate] fail reason=answeredCharacterNameButAskedUserName reply=\"\(trimmed)\"")
            return "answeredCharacterNameButAskedUserName"
        }
        return nil
    }

    /// 카엘이 가벼운 일상 대화(인사/음식/활동 등)를 과하게 시적/문학적으로 받는 경우를 거른다.
    /// 감정/안전/관계 사건은 캐릭터 톤을 허용하므로 여기 들어오지 않는다.
    private func naturalnessRejection(
        _ trimmed: String,
        understanding: UserMessageUnderstanding,
        context: ConversationGenerationContext
    ) -> String? {
        guard context.character.generatedAvatarKey == "nocturne-vampire" else { return nil }
        guard kaelBasicChatEvents.contains(understanding.eventType.logName) else { return nil }
        let heavy = kaelHeavyToneWords.filter { trimmed.contains($0) }
        if !heavy.isEmpty {
            print("[NaturalnessGate] fail reason=overWorldbuiltBasicChat words=\(heavy.joined(separator: ",")) reply=\"\(trimmed)\"")
            return "overWorldbuiltBasicChat"
        }
        return nil
    }

    /// 문장 맨 앞 "화자:" 형태(짧은 단어 + 콜론)를 감지한다. 중간 콜론은 제외.
    /// 정규식: ^[가-힣A-Za-z0-9_]{1,12}\s*[:：]
    private func leadingSpeakerPrefixRange(_ text: String) -> Range<String.Index>? {
        let pattern = "^[가-힣A-Za-z0-9_]{1,12}\\s*[:：]\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        return range
    }

    /// 유저 메시지 어절이 응답에 얼마나 그대로 들어갔는지 비율(0...1).
    private func parrotRatio(user: String, reply: String) -> Double {
        let userTokens = user
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
        guard !userTokens.isEmpty else { return 0 }
        let matched = userTokens.filter { reply.contains($0) }.count
        return Double(matched) / Double(userTokens.count)
    }

    // MARK: - 공통 검증

    private func sharedVerdict(
        trimmed: String,
        context: ConversationGenerationContext,
        allowsDirectMemoryRepeat: Bool = false
    ) -> ConversationQualityVerdict {
        let lowered = trimmed.lowercased()
        for phrase in evasiveBlacklist where trimmed.contains(phrase) {
            return .rejected(reason: "evasiveBlacklist")
        }

        if context.memory.userName != nil {
            let unknownNamePhrases = [
                "아직은 모른다",
                "아직 네 이름은 모른다",
                "아직 네 이름은 내게 닿지 않았다",
                "아직은 몰라",
                "아직 네 이름은 몰라"
            ]
            for phrase in unknownNamePhrases where trimmed.contains(phrase) {
                return .rejected(reason: "knownNameContradicted")
            }
        }

        for phrase in genericPhrases where lowered.contains(phrase.lowercased()) {
            return .rejected(reason: "genericPhrase")
        }

        // 질문·감정 반응이 전혀 없는 평탄한 문장 거르기.
        let hasEmotionMarker = emotionMarkers.contains { trimmed.contains($0) }
        if !hasEmotionMarker {
            return .rejected(reason: "noEmotionMarker")
        }

        // 유저/관계를 향한 반응 단어가 하나도 없으면 캐릭터 대화로 보기 어렵다.
        let hasReactionWord = reactionWords.contains { trimmed.contains($0) }
        if !hasReactionWord {
            return .rejected(reason: "noReactionWord")
        }

        // 같은 어절을 3번 이상 반복하면 generic 반복으로 본다.
        if hasExcessiveRepetition(trimmed) {
            return .rejected(reason: "repetition")
        }

        // 직전 캐릭터 발화와 50% 이상 겹치면 같은 말 반복으로 보고 거른다.
        if !allowsDirectMemoryRepeat,
           let previousCharacter = context.messages.last(where: { $0.sender == .character })?.text,
           previousCharacter.count >= 6,
           similarityRatio(previousCharacter, trimmed) >= 0.5 {
            return .rejected(reason: "repeatsPreviousLine")
        }

        if !allowsDirectMemoryRepeat {
            let recentCharacterMessages = context.messages
                .filter { $0.sender == .character }
                .suffix(5)
                .map(\.text)
            for previous in recentCharacterMessages where previous.count >= 6 {
                if similarityRatio(previous, trimmed) >= 0.65 {
                    return .rejected(reason: "repeatsRecentLine")
                }
                if sentenceShape(previous) == sentenceShape(trimmed) {
                    return .rejected(reason: "repeatsRecentStructure")
                }
            }
        }

        return .accepted
    }

    private func containsDirectAnswerToken(
        _ text: String,
        understanding: UserMessageUnderstanding,
        context: ConversationGenerationContext
    ) -> Bool {
        if let knownName = understanding.knownUserName, text.contains(knownName) { return true }
        if let extracted = understanding.extractedUserName, text.contains(extracted) { return true }
        if text.contains(context.character.name) { return true }
        let tokens = [
            "나는", "내가", "이름", "기억", "알아", "모른", "몰라", "불러", "부르",
            "사이", "관계", "뜻", "말", "방금", "네가", "너는", "여기"
        ]
        return tokens.contains { text.contains($0) }
    }

    private func metaphorReplacesDirectAnswer(
        _ firstClause: String,
        understanding: UserMessageUnderstanding,
        context: ConversationGenerationContext
    ) -> Bool {
        guard understanding.requiresDirectAnswer else { return false }
        if containsDirectAnswerToken(firstClause, understanding: understanding, context: context) {
            return false
        }
        let metaphorTokens = ["밤", "그림자", "정적", "기척", "어둠", "경계", "계약"]
        return metaphorTokens.contains { firstClause.contains($0) }
    }

    private func sentenceShape(_ text: String) -> String {
        text
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map { token -> String in
                if token.contains("?") { return "Q" }
                if token.contains("!") { return "E" }
                if token.count <= 2 { return "S" }
                return "W"
            }
            .joined(separator: "-")
    }

    private func firstClause(_ text: String) -> String {
        let separators: [Character] = [".", "?", "!", "。", "\n"]
        if let index = text.firstIndex(where: { separators.contains($0) }) {
            return String(text[..<index])
        }
        return text
    }

    private func hasExcessiveRepetition(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        guard words.count > 3 else { return false }
        var counts: [String: Int] = [:]
        for word in words where word.count >= 2 {
            counts[word, default: 0] += 1
            if counts[word]! >= 3 { return true }
        }
        return false
    }

    /// 두 문장이 공유하는 어절 비율(0...1). 직전 발화 반복 감지에 쓴다.
    private func similarityRatio(_ a: String, _ b: String) -> Double {
        let tokensA = Set(a.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 })
        let tokensB = Set(b.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 })
        guard !tokensA.isEmpty, !tokensB.isEmpty else { return 0 }
        let shared = tokensA.intersection(tokensB).count
        return Double(shared) / Double(min(tokensA.count, tokensB.count))
    }
}
