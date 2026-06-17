import Foundation

struct CompositeConversationGenerator: ConversationGenerating {
    private let nativeGenerator: NativeFoundationModelConversationGenerator
    private let fallbackGenerator: LocalConversationScenarioGenerator

    init(
        nativeGenerator: NativeFoundationModelConversationGenerator = NativeFoundationModelConversationGenerator(),
        fallbackGenerator: LocalConversationScenarioGenerator = LocalConversationScenarioGenerator()
    ) {
        self.nativeGenerator = nativeGenerator
        self.fallbackGenerator = fallbackGenerator
    }

    var generationMode: ConversationGenerationMode {
        availabilityStatus().isAvailable ? .nativeFoundationModel : .localDeterministicFallback
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
        do {
            let message = try await nativeGenerator.generateReply(context: context)
            print("[ConversationGenerator] finalMode=\(message.generationMode?.rawValue ?? "unknown")")
            return message
        } catch {
            print("[NativeLLM] generation=failed reason=\(error.localizedDescription)")
            print("[NativeLLM] fallback=localDeterministicFallback reason=\(error.localizedDescription)")
            await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            let message = try await fallbackGenerator.generateReply(context: context)
            print("[ConversationGenerator] finalMode=\(message.generationMode?.rawValue ?? "unknown")")
            return message
        }
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        do {
            let message = try await nativeGenerator.generateScenarioMessage(scenario: scenario, context: context)
            print("[ConversationGenerator] finalMode=\(message.generationMode?.rawValue ?? "unknown")")
            return message
        } catch {
            print("[NativeLLM] generation=failed reason=\(error.localizedDescription)")
            print("[NativeLLM] fallback=localDeterministicFallback reason=\(error.localizedDescription)")
            await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            let message = try await fallbackGenerator.generateScenarioMessage(scenario: scenario, context: context)
            print("[ConversationGenerator] finalMode=\(message.generationMode?.rawValue ?? "unknown")")
            return message
        }
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        do {
            let moment = try await nativeGenerator.generateMomentMessage(context: context)
            print("[ConversationGenerator] finalMode=\(moment.generationMode?.rawValue ?? "unknown")")
            return moment
        } catch {
            print("[NativeLLM] generation=failed reason=\(error.localizedDescription)")
            print("[NativeLLM] fallback=localDeterministicFallback reason=\(error.localizedDescription)")
            await NativeLLMDiagnosticsCenter.shared.markFallback(reason: error.localizedDescription)
            let moment = try await fallbackGenerator.generateMomentMessage(context: context)
            print("[ConversationGenerator] finalMode=\(moment.generationMode?.rawValue ?? "unknown")")
            return moment
        }
    }
}
