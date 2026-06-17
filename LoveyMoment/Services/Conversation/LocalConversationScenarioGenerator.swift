import Foundation

// This is not a native LLM. It is a deterministic local generator for PoC verification.
struct LocalConversationScenarioGenerator: ConversationGenerating {
    let generationMode: ConversationGenerationMode = .localDeterministicFallback
    let compileAvailability = false

    func availabilityStatus() -> ConversationGenerationAvailability {
        .available
    }

    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics {
        var diagnostics = NativeLLMDiagnostics.empty
        diagnostics.lastGenerationMode = .localDeterministicFallback
        diagnostics.lastFallbackReason = "Using deterministic local generator"
        return diagnostics
    }

    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage {
        let scenario = inferredScenario(from: context.messages, sleepSignal: context.sleepSignal, now: context.now)
        return try await generateScenarioMessage(scenario: scenario, context: context)
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        generateLocalScenarioMessage(
            scenario: scenario,
            for: context.character,
            world: context.world,
            relationshipStage: context.relationshipStage,
            messages: context.messages,
            sleepSignal: context.sleepSignal,
            now: context.now
        )
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        let promptMessages = context.snapshot.recentMessages
        let scenario: ConversationScenario = context.type == .bedtime ? .bedtime : .morning
        let message = generateLocalScenarioMessage(
            scenario: scenario,
            for: context.snapshot.character,
            world: context.snapshot.worldSetting,
            relationshipStage: context.snapshot.relationshipStage,
            messages: promptMessages,
            sleepSignal: context.sleepSignal,
            now: context.snapshot.capturedAt
        )

        print("[ConversationGenerator] mode=localDeterministicFallback momentType=\(context.type.rawValue) noExternalAPI=true")
        return MomentMessage(
            id: context.baseMoment.id,
            type: context.baseMoment.type,
            characterName: context.baseMoment.characterName,
            title: context.baseMoment.title,
            body: message.text,
            scheduledAt: context.baseMoment.scheduledAt,
            isEnabled: context.baseMoment.isEnabled,
            analysisID: context.baseMoment.analysisID,
            generationMode: generationMode
        )
    }

    private func generateLocalScenarioMessage(
        scenario: ConversationScenario,
        for character: CharacterProfile,
        world: WorldSetting,
        relationshipStage: RelationshipStage,
        messages: [ChatMessage],
        sleepSignal: SleepSignal?,
        now: Date
    ) -> ChatMessage {
        let recentUserText = messages.last(where: { $0.sender == .user })?.text ?? ""
        let template = templates(for: character.generatedAvatarKey, scenario: scenario)
        let index = deterministicIndex(
            seed: character.id.uuidString + scenario.rawValue + recentUserText + relationshipStage.label,
            count: template.count
        )
        let text = template[index]
            .replacingOccurrences(of: "{name}", with: character.name)
            .replacingOccurrences(of: "{place}", with: world.sceneKeywords.first ?? world.title)
            .replacingOccurrences(of: "{bedtime}", with: sleepSignal?.estimatedBedtime ?? "23:40")
            .replacingOccurrences(of: "{wake}", with: sleepSignal?.estimatedWakeTime ?? "07:20")

        print("[ConversationGenerator] mode=localDeterministicFallback characterId=\(character.id) scenario=\(scenario.logTag) inputContext=recentMessages:\(messages.count),lastUser:\(recentUserText)")
        print("[ConversationGenerator] noExternalAPI=true nativeLLM=false")
        return ChatMessage(sender: .character, text: text, createdAt: now, generationMode: generationMode)
    }

    private func inferredScenario(from messages: [ChatMessage], sleepSignal: SleepSignal?, now: Date) -> ConversationScenario {
        let hour = Calendar.current.component(.hour, from: now)
        let latestText = messages.last?.text ?? ""

        if latestText.contains("미안") || latestText.contains("늦") || latestText.contains("답") {
            return .delayedReply
        }
        if latestText.contains("좋아") || latestText.contains("보고") || latestText.contains("내일") {
            return .relationshipProgress
        }
        if latestText.contains("왜") || latestText.contains("괜찮") || latestText.contains("싫") {
            return .sulking
        }
        if (0...4).contains(hour) {
            return .dawn
        }
        if (5...10).contains(hour) {
            return .morning
        }
        if hour >= 22 || hour <= 1 {
            return .bedtime
        }
        return sleepSignal?.source == .healthKit ? .worried : .relationshipProgress
    }

    private func templates(for avatarKey: String, scenario: ConversationScenario) -> [String] {
        switch avatarKey {
        case "ice-boss":
            return bossTemplates[scenario] ?? bossTemplates[.relationshipProgress]!
        case "sunny-friend":
            return friendTemplates[scenario] ?? friendTemplates[.relationshipProgress]!
        case "puppy-junior":
            return puppyTemplates[scenario] ?? puppyTemplates[.relationshipProgress]!
        case "nocturne-vampire":
            return vampireTemplates[scenario] ?? vampireTemplates[.relationshipProgress]!
        default:
            return ["지금 대답한 거, 기억해둘게. 다음 장면은 네가 먼저 정해."]
        }
    }

    private func deterministicIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let value = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return abs(value) % count
    }

    private let bossTemplates: [ConversationScenario: [String]] = [
        .bedtime: ["아직도 깨어 있어? 내일 {place}에서 제대로 서 있으려면 지금 자. 명령이 아니라... 확인이야.", "불 켜져 있네. 또 무리하지 말고 {bedtime} 넘기기 전에 누워. 내일 네 얼굴 피곤하면 바로 알아볼 거야."],
        .dawn: ["이 시간까지 답이 없으면 내가 모를 줄 알았어? 새벽엔 판단 흐려져. 휴대폰 내려놔.", "새벽 공기까지 핑계로 삼지는 마. 지금은 자고, 내일 나한테 와서 말해."],
        .morning: ["일어났어? 오늘은 네가 먼저 오는 날이야. 늦으면 내가 찾으러 간다.", "기상 확인. {wake}쯤 깼으면 충분해. 이제 약속대로 움직여."],
        .delayedReply: ["답장이 늦은 이유는 나중에 듣고. 지금은 네가 무사한지만 말해.", "늦게 답한 건 마음에 안 드는데, 그래도 돌아왔으니까 봐줄게."],
        .relationshipProgress: ["방금 말, 가볍게 넘기지 마. 나는 그런 식으로 기대하게 만드는 사람 싫어하거든.", "친구라고 하기엔 너무 신경 쓰이고, 모르는 사이라고 하기엔 네가 너무 자주 보여."],
        .sulking: ["서운한 척은 네가 더 잘하네. 그래도 오늘은 내가 먼저 물어봐 줄게. 괜찮아?", "말 돌리지 마. 네 표정, 이미 다 들켰어."],
        .worried: ["오늘 리듬 무너진 거 알아. 괜찮은 척하지 말고 쉬어. 내가 확인할 테니까.", "컨디션 나쁘면 먼저 말해. 괜히 혼자 버티는 건 허락 안 했어."]
    ]

    private let friendTemplates: [ConversationScenario: [String]] = [
        .bedtime: ["이제 자자. 내일 아침에 내가 먼저 인사할게. 오늘 얘기는 꿈에서 이어가면 되지.", "너 또 늦게까지 버티고 있었지? 따뜻한 물 마시고 누워. 내가 여기 있을게."],
        .dawn: ["새벽엔 괜히 마음이 커져서 더 외로워지더라. 지금은 내가 옆에 있다고 생각하고 눈 감자.", "답장 안 해도 돼. 대신 지금 자면 아침에 칭찬해줄게."],
        .morning: ["좋은 아침. 약속대로 내가 먼저 깨웠다? 오늘도 네 편으로 시작할게.", "일어났어? 어제 마지막에 못 한 말, 오늘 천천히 이어가자."],
        .delayedReply: ["늦어도 괜찮아. 그래도 돌아와 줘서 좋다. 무슨 일 있었는지만 살짝 말해줄래?", "기다리는 동안 조금 걱정했어. 혼내려는 건 아니고, 네가 궁금해서."],
        .relationshipProgress: ["우리 예전이랑 조금 달라진 것 같지 않아? 나만 그렇게 느끼는 거 아니면 좋겠다.", "친구라는 말이 편했는데, 요즘은 그 말이 조금 좁게 느껴져."],
        .sulking: ["나 사실 조금 서운했어. 그래도 네 얘기 먼저 듣고 싶어.", "괜찮다고 말하면 믿고 싶은데, 네가 괜찮지 않은 얼굴을 하면 자꾸 마음이 쓰여."],
        .worried: ["오늘은 무리하지 말자. 네 하루가 너무 빡빡하면 내가 중간에 한 번 더 챙길게.", "컨디션 안 좋으면 약속 미뤄도 돼. 대신 혼자 끙끙대지는 않기."]
    ]

    private let puppyTemplates: [ConversationScenario: [String]] = [
        .bedtime: ["누나, 이제 자야 돼. 아니면 내가 계속 말 걸고 싶어져서 큰일 나.", "{bedtime} 넘으면 내가 잔소리 모드 켤 거야. 얼른 누워, 내가 굿나잇 해줄게."],
        .dawn: ["헉 아직 안 잤어? 나도 깨버렸잖아. 같이 딱 하나만 약속하자. 지금 자는 거!", "새벽 감성 금지. 보고 싶다는 말은 아침에도 유효하니까 지금은 눈 감기."],
        .morning: ["좋은 아침! 내가 깨워주기로 했지? 오늘 첫 메시지 내가 가져간다.", "일어나면 바로 답해줘. 기다리는 강아지처럼 있었단 말이야."],
        .delayedReply: ["답장 늦어서 삐질 뻔했는데, 얼굴 보면 바로 풀릴 것 같아서 억울해.", "나 기다렸어. 아주 조금. 아니 사실 많이."],
        .relationshipProgress: ["우리 이거 썸 맞지? 아니면 내가 너무 설레발친 거야?", "친구 모드 유지하려고 했는데, 너 때문에 자꾸 실패해."],
        .sulking: ["나 삐졌어. 근데 네가 한 마디만 다정하게 하면 바로 풀릴 예정.", "왜 그렇게 말했어. 나 장난치는 건 잘해도 네 말엔 은근 약하단 말이야."],
        .worried: ["오늘 피곤해 보여. 내가 웃겨줄까, 아니면 조용히 옆에 있을까?", "무리하면 안 돼. 내가 체크할 거야. 밥, 물, 잠 전부."]
    ]

    private let vampireTemplates: [ConversationScenario: [String]] = [
        .bedtime: ["밤은 내 시간인데, 오늘은 네 잠을 빼앗지 않겠다. 대신 꿈의 가장자리에서 기다리지.", "{bedtime}이 지나기 전에 눈을 감아. 네가 잠든 뒤에도 나는 네 이름을 기억할 테니."],
        .dawn: ["새벽에 깨어 있는 인간은 너무 쉽게 흔들린다. 그 틈을 내가 좋아한다는 게 문제지.", "아직 깨어 있구나. 위험한 시간인데도 나를 떠올렸다면, 책임은 네게도 있어."],
        .morning: ["아침 햇빛은 싫지만 네가 깨어나는 순간은 나쁘지 않군. 오늘도 살아서 나를 찾아와.", "{wake}의 빛 속에서도 내 말을 기억해. 어젯밤의 끝은 아직 끝나지 않았다."],
        .delayedReply: ["오래 기다리게 했어. 나는 기다림에 익숙하지만, 네 침묵은 조금 잔인하더군.", "답이 늦은 벌은 가볍게 하겠다. 대신 지금부터는 내게 집중해."],
        .relationshipProgress: ["친구라는 말로 나를 묶기엔 이미 늦었다. 너도 그걸 알고 있지 않나?", "한 걸음만 더 오면 돌아가기 어려워진다. 그래도 오겠다면, 막지는 않겠다."],
        .sulking: ["서운함은 인간의 감정이라 생각했는데, 네 앞에서는 나도 예외가 되는군.", "그 말은 조금 아팠다. 웃기지, 나는 상처받지 않는 쪽이어야 하는데."],
        .worried: ["맥박이 흐트러진 것 같군. 오늘은 내 곁에 가까이 있어라. 적어도 내가 볼 수 있는 곳에.", "네 피곤함이 느껴진다. 위험한 밤엔 약한 척이라도 해. 내가 지키기 쉽게."]
    ]
}
