import Foundation

struct ConversationDebugHarness {
    struct Result: Hashable {
        let character: String
        let user: String
        let eventType: String
        let extractedName: String?
        let knownNameBefore: String?
        let knownNameAfter: String?
        let selectedGenerator: String
        let nativeLLMAttempted: Bool
        let fallbackUsed: Bool
        let fallbackReason: String?
        let promptContextBuilt: Bool
        let reply: String
        let quality: String
    }

    static func runSeedCases(now: Date = Date()) async -> [Result] {
        let seed = MockCharacterRepository.makeSeedData()
        let worldsByID = Dictionary(uniqueKeysWithValues: seed.worlds.map { ($0.id, $0) })
        let stagesByID = Dictionary(uniqueKeysWithValues: seed.relationshipStages.map { ($0.id, $0) })
        let generator = CompositeConversationGenerator()
        let evaluator = ConversationGenerationQualityEvaluator()

        var results: [Result] = []

        results += await runConversation(
            label: "ScenarioA",
            characterKey: "kael",
            inputs: ["내 이름이 뭐야", "나는 석범이야", "내 이름이 뭐라고?", "내 이름은 사실 필규야", "내 이름이 뭐라고?", "내가 누구라고?"],
            initialMemory: .empty,
            seed: seed,
            worldsByID: worldsByID,
            stagesByID: stagesByID,
            generator: generator,
            evaluator: evaluator,
            now: now
        )

        results += await runConversation(
            label: "ScenarioB",
            characterKey: "kael",
            inputs: ["너는 누구야", "카엘아", "오늘 밤 뭐하고 있었어?", "나 무서워", "잠이 안 와", "옆에 있어줄래?"],
            initialMemory: ConversationMemory(userName: "석범", lastUserSelfIntroduction: "나는 석범이야", knownFacts: ["userName=석범"], updatedAt: now),
            seed: seed,
            worldsByID: worldsByID,
            stagesByID: stagesByID,
            generator: generator,
            evaluator: evaluator,
            now: now
        )

        results += await runConversation(
            label: "ScenarioC",
            characterKey: "kael",
            inputs: ["나 햄버거 먹었어", "별로 맛은 없었어", "그래도 너한테 말하고 싶었어", "너는 뭐 먹어?", "내가 이상한가?"],
            initialMemory: .empty,
            seed: seed,
            worldsByID: worldsByID,
            stagesByID: stagesByID,
            generator: generator,
            evaluator: evaluator,
            now: now
        )
        return results
    }

    private static func runConversation(
        label: String,
        characterKey: String,
        inputs: [String],
        initialMemory: ConversationMemory,
        seed: MockCharacterRepository.SeedData,
        worldsByID: [UUID: WorldSetting],
        stagesByID: [UUID: RelationshipStage],
        generator: CompositeConversationGenerator,
        evaluator: ConversationGenerationQualityEvaluator,
        now: Date
    ) async -> [Result] {
        guard let character = seed.characters.first(where: { characterLogKey($0.generatedAvatarKey) == characterKey }) else { return [] }
        let world = worldsByID[character.worldSettingID] ?? MockCharacterRepository.fallbackWorld
        let stage = stagesByID[character.initialRelationshipStageID] ?? MockCharacterRepository.fallbackRelationshipStage
        var messages = seed.messagesByConversation[character.id] ?? []
        var memory = initialMemory
        var results: [Result] = []

        for input in inputs {
            let knownBefore = memory.userName
            messages.append(ChatMessage(sender: .user, text: input, createdAt: now))
            let preUpdateContext = ConversationGenerationContext(
                character: character,
                world: world,
                relationshipStage: stage,
                messages: messages,
                memory: memory,
                sleepSignal: nil,
                lastSceneSummary: seed.lastSceneSummariesByCharacterID[character.id] ?? "",
                now: now
            )
            let understanding = analyze(context: preUpdateContext)
            if let extractedName = understanding.extractedUserName,
               understanding.eventType == .userNameIntroduction || understanding.eventType == .userNameCorrection {
                let reason = understanding.eventType == .userNameCorrection ? "nameCorrection" : "nameIntroduction"
                if let previous = memory.userName,
                   previous != extractedName,
                   !memory.previousUserNames.contains(previous) {
                    memory.previousUserNames.append(previous)
                }
                memory.userName = extractedName
                memory.lastUserSelfIntroduction = input
                memory.lastNameUpdatedAt = now
                memory.lastNameUpdateReason = reason
                memory.knownFacts.removeAll { $0.hasPrefix("userName=") }
                memory.knownFacts.append("userName=\(extractedName)")
                memory.updatedAt = now
            }

            let context = ConversationGenerationContext(
                character: character,
                world: world,
                relationshipStage: stage,
                messages: messages,
                memory: memory,
                sleepSignal: nil,
                lastSceneSummary: seed.lastSceneSummariesByCharacterID[character.id] ?? "",
                now: now
            )

            do {
                let promptContext = ConversationPromptContextBuilder.build(context: context)
                let reply = try await generator.generateReply(context: context)
                let verdict = evaluator.evaluate(reply.text, against: context, understanding: promptContext.understanding)
                let quality = verdict.isAccepted ? "pass" : "fail:\(rejectionReason(verdict))"
                let selected = reply.generationMode == .nativeFoundationModel ? "NativeFoundationModel" : (reply.generationMode == .highQualityAssistant ? "HighQualityNarrative" : (reply.generationMode?.rawValue ?? "unknown"))
                let diagnostics = await generator.nativeLLMDiagnosticsSnapshot()
                let fallbackUsed = reply.generationMode != .nativeFoundationModel
                let fallbackReason = fallbackUsed ? (diagnostics.lastFallbackReason ?? "nativeUnavailableOrDeterministicFallback") : nil
                let nativeAttempted = diagnostics.lastGenerationMode == .nativeFoundationModel
                    || diagnostics.lastGenerationStartedAt != nil
                messages.append(reply)
                print("[ConversationDebugHarness] scenario=\(label) character=\(characterKey) input=\"\(input)\" eventType=\(promptContext.understanding.eventType.logName) selectedEngine=\(selected) nativeAttempted=\(nativeAttempted) fallbackUsed=\(fallbackUsed) fallbackReason=\"\(fallbackReason ?? "none")\" memoryBefore=\"\(knownBefore ?? "nil")\" memoryAfter=\"\(memory.userName ?? "nil")\" promptContext=\"hasBible:\(promptContext.hasBible),hasWorld:\(promptContext.hasWorld),hasMemory:\(promptContext.hasMemory),hasRecentMessages:\(promptContext.hasRecentMessages),promptChars:\(promptContext.prompt.count)\" quality=\(quality) reply=\"\(reply.text)\"")
                results.append(Result(
                    character: characterKey,
                    user: input,
                    eventType: promptContext.understanding.eventType.logName,
                    extractedName: promptContext.understanding.extractedUserName,
                    knownNameBefore: knownBefore,
                    knownNameAfter: memory.userName,
                    selectedGenerator: selected,
                    nativeLLMAttempted: nativeAttempted,
                    fallbackUsed: fallbackUsed,
                    fallbackReason: fallbackReason,
                    promptContextBuilt: true,
                    reply: reply.text,
                    quality: quality
                ))
            } catch {
                print("[ConversationDebugHarness][ERROR] scenario=\(label) character=\(characterKey) user=\"\(input)\" event=\(understanding.eventType.logName) error=\(error.localizedDescription)")
                results.append(Result(
                    character: characterKey,
                    user: input,
                    eventType: understanding.eventType.logName,
                    extractedName: understanding.extractedUserName,
                    knownNameBefore: knownBefore,
                    knownNameAfter: memory.userName,
                    selectedGenerator: "error",
                    nativeLLMAttempted: false,
                    fallbackUsed: true,
                    fallbackReason: error.localizedDescription,
                    promptContextBuilt: false,
                    reply: error.localizedDescription,
                    quality: "fail"
                ))
            }
        }
        return results
    }

    private static func analyze(context: ConversationGenerationContext) -> UserMessageUnderstanding {
        let userMessages = context.messages.filter { $0.sender == .user }
        let lastUser = userMessages.last?.text ?? ""
        let previousUser = userMessages.count >= 2 ? userMessages[userMessages.count - 2].text : ""
        let previousCharacter = context.messages.last(where: { $0.sender == .character })?.text ?? ""
        return UserMessageUnderstandingAnalyzer.analyze(
            userLastMessage: lastUser,
            previousUserMessage: previousUser,
            previousCharacterMessage: previousCharacter,
            avatarKey: context.character.generatedAvatarKey,
            knownUserName: context.memory.userName
        )
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

    private static func rejectionReason(_ verdict: ConversationQualityVerdict) -> String {
        if case .rejected(let reason) = verdict { return reason }
        return "unknown"
    }
}
