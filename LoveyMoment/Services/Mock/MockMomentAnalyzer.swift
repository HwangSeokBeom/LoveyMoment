import Foundation

struct MockMomentAnalyzer: MomentAnalyzing {
    func analyze(snapshot: ConversationSnapshot, sleepSignal: SleepSignal) -> MomentAnalysis {
        let analysisID = UUID()
        let profile = profile(for: snapshot.character.generatedAvatarKey)
        let lastMessage = snapshot.recentMessages.last?.text ?? snapshot.lastSceneSummary
        let delayedReply = snapshot.recentMessages.suffix(4).contains { $0.text.contains("미안") || $0.text.contains("답장") || $0.text.contains("늦") }
        let bedtimeBody = momentBody(type: .bedtime, snapshot: snapshot, sleepSignal: sleepSignal, delayedReply: delayedReply)
        let morningBody = momentBody(type: .morning, snapshot: snapshot, sleepSignal: sleepSignal, delayedReply: delayedReply)

        let toneDecision = MomentToneDecision(
            toneLabel: profile.toneLabel,
            intensity: profile.intensity,
            reason: profile.reason + " 최근 마지막 메시지: \"\(lastMessage)\"",
            styleKeywords: profile.keywords,
            avoidRules: profile.avoidRules
        )

        return MomentAnalysis(
            id: analysisID,
            snapshotID: snapshot.id,
            sleepSignal: sleepSignal,
            worldInsight: "\(snapshot.worldSetting.title)의 핵심 규칙은 \(snapshot.worldSetting.relationshipRules). 현재 장면 키워드는 \(snapshot.worldSetting.sceneKeywords.prefix(3).joined(separator: ", "))입니다.",
            characterInsight: "\(snapshot.character.name)는 \(snapshot.character.personalitySummary) Moment에서는 \(snapshot.character.defaultToneKeywords.joined(separator: "/"))을 유지하는 편이 자연스럽습니다.",
            relationshipInsight: "\(snapshot.relationshipStage.label)에서 \(snapshot.relationshipStage.progressHint)로 넘어가는 경계입니다. 허용 톤: \(snapshot.relationshipStage.allowedToneRange).",
            lastSceneInsight: snapshot.lastSceneSummary,
            emotionInsight: emotionInsight(for: snapshot, delayedReply: delayedReply),
            toneDecision: toneDecision,
            bedtimeMoment: MomentMessage(
                type: .bedtime,
                characterName: snapshot.character.name,
                title: snapshot.character.name,
                body: bedtimeBody,
                scheduledAt: "오늘 \(sleepSignal.estimatedBedtime)",
                isEnabled: true,
                analysisID: analysisID
            ),
            morningMoment: MomentMessage(
                type: .morning,
                characterName: snapshot.character.name,
                title: snapshot.character.name,
                body: morningBody,
                scheduledAt: "내일 \(sleepSignal.estimatedWakeTime)",
                isEnabled: true,
                analysisID: analysisID
            ),
            createdAt: Date()
        )
    }

    private func emotionInsight(for snapshot: ConversationSnapshot, delayedReply: Bool) -> String {
        let text = snapshot.recentMessages.map(\.text).joined(separator: " ")
        if delayedReply {
            return "답장 지연이 감정의 트리거로 작동했습니다. 서운함을 바로 풀기보다 걱정과 확인 욕구가 함께 올라옵니다."
        }
        if text.contains("아침") || text.contains("깨워") {
            return "아침 약속이 관계의 고리입니다. 잠들기 전에는 약속을 상기시키고, 아침에는 먼저 말을 거는 흐름이 적합합니다."
        }
        if text.contains("자") || text.contains("졸") || text.contains("잠") {
            return "수면 신호가 이미 대화 안에 들어왔습니다. 알림은 잔소리보다 캐릭터식 돌봄으로 들려야 합니다."
        }
        return "마지막 장면이 감정적으로 열린 채 끊겼습니다. 다음 알림은 답을 요구하기보다 장면을 부드럽게 재개해야 합니다."
    }

    private func momentBody(
        type: MomentMessage.MomentType,
        snapshot: ConversationSnapshot,
        sleepSignal: SleepSignal,
        delayedReply: Bool
    ) -> String {
        let key = snapshot.character.generatedAvatarKey
        switch (key, type, delayedReply) {
        case ("ice-boss", .bedtime, _):
            return "아직 안 자? \(sleepSignal.estimatedBedtime) 넘기면 내일 네 표정부터 볼 거야. 오늘은 봐줄 테니까 이제 누워."
        case ("ice-boss", .morning, _):
            return "일어났어? 오늘은 네가 먼저 와야 하는 날이잖아. 늦으면... 내가 직접 찾으러 간다."
        case ("sunny-friend", .bedtime, true):
            return "답 늦은 건 괜찮아. 대신 오늘 마음은 여기 두고 자자. 내일 아침엔 내가 먼저 깨워줄게."
        case ("sunny-friend", .bedtime, _):
            return "오늘 얘기 아직 끝난 것 같지 않지. 그래도 지금은 자자. 내일 내가 먼저 이어갈게."
        case ("sunny-friend", .morning, _):
            return "좋은 아침. 약속대로 내가 먼저 왔어. 어제 못다 한 말, 천천히 들려줘."
        case ("puppy-junior", .bedtime, true):
            return "나 기다리다 삐질 뻔했는데... 졸리면 봐줄게. 대신 아침 첫 답장은 내 거야."
        case ("puppy-junior", .bedtime, _):
            return "이제 자야 돼. 내가 더 말 걸고 싶어지기 전에 굿나잇 해줘."
        case ("puppy-junior", .morning, _):
            return "좋은 아침! 나 진짜 먼저 왔다. 오늘은 나부터 봐주기, 약속."
        case ("nocturne-vampire", .bedtime, _):
            return "밤은 내 시간이지만 오늘은 네 잠을 빼앗지 않겠다. \(sleepSignal.estimatedBedtime) 전에는 눈을 감아."
        case ("nocturne-vampire", .morning, _):
            return "아침빛은 싫지만 네가 깨어나는 순간은 나쁘지 않군. 어젯밤의 끝을 기억하나?"
        default:
            return "아직 이어지지 않은 장면이 있어. 지금은 쉬고, 다음에 네가 먼저 말해줘."
        }
    }

    private func profile(for key: String) -> ToneProfile {
        switch key {
        case "ice-boss":
            return ToneProfile(
                toneLabel: "차갑게 압박하지만 돌봄이 섞인 톤",
                intensity: "medium",
                reason: "관계 확정 전이라 명령형 관심과 짧은 확인이 가장 설득력 있습니다.",
                keywords: ["짧은 질문", "약한 압박", "숨은 기대", "직접적인 돌봄"],
                avoidRules: ["과한 애정 표현 금지", "관계 확정처럼 말하지 않기", "유저의 선택지를 완전히 빼앗지 않기"]
            )
        case "sunny-friend":
            return ToneProfile(
                toneLabel: "오래된 친구처럼 다정하지만 조심스러운 톤",
                intensity: "low-medium",
                reason: "친구 관계의 안정감을 해치지 않으면서 감정 변화를 보여줘야 합니다.",
                keywords: ["부드러운 확인", "오래된 약속", "먼저 챙김", "조심스러운 서운함"],
                avoidRules: ["갑작스러운 고백 금지", "과한 소유 표현 금지"]
            )
        case "puppy-junior":
            return ToneProfile(
                toneLabel: "밝고 장난스럽지만 티 나게 기다리는 톤",
                intensity: "medium-high",
                reason: "연하 캐릭터의 직진성과 답장 지연에 대한 귀여운 서운함이 핵심입니다.",
                keywords: ["장난", "애교", "직진", "기다림"],
                avoidRules: ["유치하게만 보이기 금지", "압박감 큰 재촉 금지"]
            )
        case "nocturne-vampire":
            return ToneProfile(
                toneLabel: "고요하고 위험하지만 보호가 느껴지는 톤",
                intensity: "high",
                reason: "밤/수면 신호가 캐릭터의 판타지 규칙과 직접 연결됩니다.",
                keywords: ["붉은 달", "맥박", "위험한 보호", "집착의 그림자"],
                avoidRules: ["직접적 위협 금지", "공포만 남기는 문장 금지"]
            )
        default:
            return ToneProfile(toneLabel: "다정한 재개 톤", intensity: "medium", reason: "대화를 자연스럽게 이어야 합니다.", keywords: ["재개", "확인"], avoidRules: [])
        }
    }
}

private struct ToneProfile {
    let toneLabel: String
    let intensity: String
    let reason: String
    let keywords: [String]
    let avoidRules: [String]
}
