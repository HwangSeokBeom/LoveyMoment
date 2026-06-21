import Foundation

/// ChatView 대화 생성 라우터.
/// Auto/nativeFirst에서는 Native FoundationModels를 먼저 시도하고, unavailable/fail/quality fail일 때만
/// 결정형 내러티브 생성기로 폴백한다. deterministicOnly/diagnosticsOnly는 평가·제출 안정성용 스위치다.
struct CompositeConversationGenerator: ConversationGenerating {
    private let serverGenerator: ServerLLMConversationGenerator
    private let nativeGenerator: NativeFoundationModelConversationGenerator
    private let highQualityGenerator: HighQualityNarrativeConversationGenerator
    private let fallbackGenerator: LocalConversationScenarioGenerator
    private let evaluator = ConversationGenerationQualityEvaluator()

    init(
        serverGenerator: ServerLLMConversationGenerator = ServerLLMConversationGenerator(),
        nativeGenerator: NativeFoundationModelConversationGenerator = NativeFoundationModelConversationGenerator(),
        highQualityGenerator: HighQualityNarrativeConversationGenerator = HighQualityNarrativeConversationGenerator(),
        fallbackGenerator: LocalConversationScenarioGenerator = LocalConversationScenarioGenerator()
    ) {
        self.serverGenerator = serverGenerator
        self.nativeGenerator = nativeGenerator
        self.highQualityGenerator = highQualityGenerator
        self.fallbackGenerator = fallbackGenerator
    }

    var generationMode: ConversationGenerationMode {
        let mode = ConversationEngineSettings.currentMode
        if mode.nativeChatEnabled, availabilityStatus().isAvailable {
            return .nativeFoundationModel
        }
        return .highQualityAssistant
    }

    var compileAvailability: Bool {
        nativeGenerator.compileAvailability
    }

    func availabilityStatus() -> ConversationGenerationAvailability {
        nativeGenerator.availabilityStatus()
    }

    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics {
        await nativeGenerator.nativeLLMDiagnosticsSnapshot()
    }

    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage {
        let promptContext = ConversationPromptContextBuilder.build(context: context)
        let understanding = promptContext.understanding
        let character = characterLogKey(context.character.generatedAvatarKey)
        let user = context.messages.last(where: { $0.sender == .user })?.text ?? ""
        let engineMode = ConversationEngineSettings.currentMode
        let availability = availabilityStatus()
        let nativeEnabled = engineMode.nativeChatEnabled && availability.isAvailable
        let nativeReason = nativeEnabled
            ? "mode=\(engineMode.rawValue),availability=available"
            : nativeDisabledReason(mode: engineMode, availability: availability)

        print("[ConversationRoute] enter composite character=\(character) user=\"\(user)\"")
        print("[ConversationRoute] engineMode=\(engineMode.rawValue)")
        print("[ConversationRoute] nativeEnabledForChat=\(nativeEnabled) reason=\"\(nativeReason)\"")
        print("[NativeLLM] availability=\(availability.displayText)")

        if nativeEnabled {
            print("[ConversationRoute] nativeAttempted=true")
            do {
                let nativeMessage = finalize(try await nativeGenerator.generateReply(context: context), context: context)
                let verdict = evaluator.evaluate(nativeMessage.text, against: context, understanding: understanding)
                print("[QualityGate] engine=NativeFoundationModel pass=\(verdict.isAccepted) reason=\"\(verdict.isAccepted ? "accepted" : rejectionReason(verdict))\"")
                if verdict.isAccepted {
                    print("[Fallback] used=false reason=\"nativeQualityPass\"")
                    print("[ConversationRoute] selectedEngine=NativeFoundationModel")
                    print("[LLMStatus] selectedEngine=NativeFoundationModel")
                    print("[StoryReply] finalSurface=\"\(nativeMessage.text)\"")
                    return nativeMessage
                }

                // surface/quality 실패 → repair 1회 시도.
                if let repaired = try? await nativeGenerator.repairReply(
                    context: context,
                    failedReply: nativeMessage.text,
                    reason: rejectionReason(verdict)
                ) {
                    let repairedMessage = finalize(repaired, context: context)
                    let repairVerdict = evaluator.evaluate(repairedMessage.text, against: context, understanding: understanding)
                    print("[QualityGate] engine=NativeFoundationModelRepair pass=\(repairVerdict.isAccepted) reason=\"\(repairVerdict.isAccepted ? "accepted" : rejectionReason(repairVerdict))\"")
                    if repairVerdict.isAccepted {
                        print("[ConversationRoute] selectedEngine=NativeFoundationModelRepair")
                        print("[LLMStatus] selectedEngine=NativeFoundationModelRepair")
                        print("[StoryReply] finalSurface=\"\(repairedMessage.text)\"")
                        return repairedMessage
                    }
                }

                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: "quality:\(rejectionReason(verdict))")
                return try await deterministicFallback(
                    context: context,
                    understanding: understanding,
                    reason: "nativeQualityFail:\(rejectionReason(verdict))"
                )
            } catch {
                print("[NativeLLM] generationFailed reason=\"\(error.localizedDescription)\"")
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: "nativeFailed:\(error.localizedDescription)")
                return try await deterministicFallback(
                    context: context,
                    understanding: understanding,
                    reason: "nativeFailed:\(error.localizedDescription)"
                )
            }
        }

        return try await deterministicFallback(
            context: context,
            understanding: understanding,
            reason: nativeReason
        )
    }

    private func deterministicFallback(
        context: ConversationGenerationContext,
        understanding: UserMessageUnderstanding,
        reason: String
    ) async throws -> ChatMessage {
        print("[Fallback] used=true reason=\"\(reason)\"")
        await NativeLLMDiagnosticsCenter.shared.markFallback(reason: reason)
        print("[ConversationRoute] try=HighQualityNarrative enabled=true reason=\"deterministicFallback\"")
        if let storyRaw = try? await highQualityGenerator.generateReply(context: context) {
            let storyMessage = finalize(storyRaw, context: context)
            let verdict = evaluator.evaluate(storyMessage.text, against: context, understanding: understanding)
            print("[QualityGate] engine=HighQualityNarrative pass=\(verdict.isAccepted) reason=\"\(verdict.isAccepted ? "accepted" : rejectionReason(verdict))\"")
            if verdict.isAccepted {
                print("[ConversationRoute] selectedEngine=HighQualityNarrative")
                print("[LLMStatus] selectedEngine=HighQualityNarrative")
                print("[StoryReply] finalSurface=\"\(storyMessage.text)\"")
                return storyMessage
            }
            print("[ConversationRoute] highQuality rejected event=\(understanding.eventType.logName) reason=\(rejectionReason(verdict)) reply=\"\(storyMessage.text)\"")
        }

        print("[ConversationRoute] try=LocalFallback reason=\"highQualityUnavailableOrRejected\"")
        let local = finalize(try await fallbackGenerator.generateReply(context: context), context: context)
        print("[QualityGate] engine=LocalFallback pass=true reason=\"emergencyFallback\"")
        print("[ConversationRoute] selectedEngine=LocalFallback")
        print("[LLMStatus] selectedEngine=LocalFallback")
        print("[StoryReply] finalSurface=\"\(local.text)\"")
        return local
    }

    /// 최종 말풍선에 들어가기 직전, 화자 prefix("카엘:"/동적 유저이름 "석범:" 등)를 제거한다.
    private func finalize(_ message: ChatMessage, context: ConversationGenerationContext) -> ChatMessage {
        var dynamicNames = context.memory.previousUserNames
        if let userName = context.memory.userName { dynamicNames.append(userName) }
        let result = ReplySurfaceSanitizer.sanitize(message.text, dynamicNames: dynamicNames)
        guard result.didChange else { return message }
        return ChatMessage(
            id: message.id,
            sender: message.sender,
            text: result.text,
            createdAt: message.createdAt,
            isMomentInserted: message.isMomentInserted,
            sourceMomentID: message.sourceMomentID,
            generationMode: message.generationMode
        )
    }

    private func nativeDisabledReason(
        mode: ConversationEngineMode,
        availability: ConversationGenerationAvailability
    ) -> String {
        if !mode.nativeChatEnabled {
            return "mode=\(mode.rawValue)"
        }
        if !availability.isAvailable {
            return "availability=\(availability.reasonText)"
        }
        return "unknown"
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        // 스토리 생성기를 먼저 사용해 안정적인 시나리오 문장을 확보한다.
        if let storyMessage = try? await highQualityGenerator.generateScenarioMessage(scenario: scenario, context: context) {
            return storyMessage
        }
        if availabilityStatus().isAvailable {
            do {
                let message = try await nativeGenerator.generateScenarioMessage(scenario: scenario, context: context)
                if evaluator.evaluate(message.text, against: context).isAccepted {
                    return message
                }
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: "lowQuality:scenario")
            } catch {
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            }
        }
        return try await fallbackGenerator.generateScenarioMessage(scenario: scenario, context: context)
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        // 알림 본문도 스토리 생성기를 우선 사용한다.
        if let storyMoment = try? await highQualityGenerator.generateMomentMessage(context: context) {
            return storyMoment
        }
        if availabilityStatus().isAvailable {
            do {
                return try await nativeGenerator.generateMomentMessage(context: context)
            } catch {
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            }
        }
        return try await fallbackGenerator.generateMomentMessage(context: context)
    }

    private func rejectionReason(_ verdict: ConversationQualityVerdict) -> String {
        if case .rejected(let reason) = verdict { return reason }
        return "unknown"
    }

    private func analyze(context: ConversationGenerationContext) -> UserMessageUnderstanding {
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

    private func characterLogKey(_ avatarKey: String) -> String {
        switch avatarKey {
        case "ice-boss": return "hana"
        case "sunny-friend": return "seoyun"
        case "puppy-junior": return "roi"
        case "nocturne-vampire": return "kael"
        default: return avatarKey
        }
    }
}
