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
        "괜찮", "보고", "곁", "기다", "쉬", "자", "와", "말해", "들을게", "챙길"
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
        "묻는다면 답은 해줄게",
        "네 생각부터 말해",
        "궁금한 게 많네",
        "하나씩 말해",
        "천천히 들을 테니까",
        "다음 장면은 네가 먼저 정해"
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

    /// 인사에 직접 반응했음을 보이는 토큰.
    private let greetingTokens: [String] = ["왔", "안녕", "인사", "기다", "오늘"]

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

        // 회피성 blacklist 문구가 들어가면 무조건 reject.
        for phrase in evasiveBlacklist where trimmed.contains(phrase) {
            return .rejected(reason: "evasiveBlacklist")
        }

        let shared = sharedVerdict(trimmed: trimmed, context: context)
        if !shared.isAccepted { return shared }

        switch understanding.eventType {
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

        case .food:
            // 음식/식사 메시지엔 직접 반응하는 토큰이 있어야 한다.
            let hasFood = foodTokens.contains { trimmed.contains($0) }
            if !hasFood {
                return .rejected(reason: "missingFoodResponse")
            }

        case .greeting:
            // 인사엔 인사로 받는 토큰이 있어야 한다.
            let hasGreeting = greetingTokens.contains { trimmed.contains($0) }
            if !hasGreeting {
                return .rejected(reason: "missingGreetingResponse")
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

    // MARK: - 공통 검증

    private func sharedVerdict(trimmed: String, context: ConversationGenerationContext) -> ConversationQualityVerdict {
        let lowered = trimmed.lowercased()
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
        if let previousCharacter = context.messages.last(where: { $0.sender == .character })?.text,
           previousCharacter.count >= 6,
           similarityRatio(previousCharacter, trimmed) >= 0.5 {
            return .rejected(reason: "repeatsPreviousLine")
        }

        return .accepted
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
