import Foundation

/// 대화 생성 우선순위를 조율한다.
/// 1. 서버 LLM(구성되면) → 2. 흐름/대화행위 기반 고품질 스토리 생성기(사실상 기본) → 3. native(가능·품질 통과 시) → 4. 로컬 결정형 폴백.
/// 스토리 생성기는 내부에서 이미 act 인지 품질 검증을 마친 라인만 반환하므로, native보다 먼저 두어 제출 안정성을 확보한다.
/// 현재 빌드에서 서버 LLM은 스텁이라 비활성이며, 흐름 기반 스토리 생성기가 사실상 기본 경로다.
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
        availabilityStatus().isAvailable ? .nativeFoundationModel : .highQualityAssistant
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
        // 1순위: 서버 LLM(구성 시). 현재는 스텁이라 unavailable → 건너뜀.
        if serverGenerator.availabilityStatus().isAvailable {
            if let message = try? await serverGenerator.generateReply(context: context),
               evaluator.evaluate(message.text, against: context).isAccepted {
                return message
            }
        }

        // 2순위(사실상 기본): 대화행위 기반 스토리 생성기. 내부에서 이미 품질 검증을 마친 라인만 돌려준다.
        // native보다 먼저 두어 무관/회피 응답이 사용자에게 도달하는 경로 자체를 없앤다.
        if let storyMessage = try? await highQualityGenerator.generateReply(context: context) {
            print("[ConversationGenerator] finalMode=highQualityStory quality=accepted")
            return storyMessage
        }

        // 3순위: native(명시적으로 가능하고 품질 통과 시에만). 스토리 생성기가 실패할 때의 안전망.
        if availabilityStatus().isAvailable {
            do {
                let message = try await nativeGenerator.generateReply(context: context)
                let verdict = evaluator.evaluate(message.text, against: context)
                if verdict.isAccepted {
                    print("[ConversationGenerator] finalMode=nativeFoundationModel quality=accepted")
                    return message
                }
                print("[ConversationGenerator] native quality=rejected reason=\(rejectionReason(verdict)) → local")
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: "lowQuality:\(rejectionReason(verdict))")
            } catch {
                print("[NativeLLM] generation=failed reason=\(error.localizedDescription) → local")
                await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            }
        }

        // 4순위: 로컬 결정형 폴백.
        return try await fallbackGenerator.generateReply(context: context)
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
}
