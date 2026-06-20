import Foundation

/// 실제 서비스의 1순위 대화 생성 경로(서버 LLM 오케스트레이션)를 위한 자리.
/// 현재 빌드에서는 네트워크 호출을 하지 않는 스텁이며, 항상 unavailable을 반환해
/// 상위 조율기가 온디바이스/결정형 스토리 생성기로 자연스럽게 넘어가게 한다.
///
/// Production would call backend LLM orchestration here
/// (e.g. POST /v1/conversations/reply with character persona + recent turns),
/// stream tokens back, and apply the same quality evaluator before display.
struct ServerLLMConversationGenerator: ConversationGenerating {
    let generationMode: ConversationGenerationMode = .highQualityAssistant
    let compileAvailability = false

    /// 백엔드 엔드포인트가 구성되면 true가 되도록 설계된 플래그. 스텁에서는 항상 false.
    private let isBackendConfigured = false

    func availabilityStatus() -> ConversationGenerationAvailability {
        // 진단 화면에서만 노출되는 개발자 라벨. 사용자 화면에는 표시하지 않는다.
        .unavailable(reason: "productionTarget=serverLLM (stub, no network)")
    }

    func nativeLLMDiagnosticsSnapshot() async -> NativeLLMDiagnostics {
        var diagnostics = NativeLLMDiagnostics.empty
        diagnostics.noExternalAPI = true
        return diagnostics
    }

    func generateReply(context: ConversationGenerationContext) async throws -> ChatMessage {
        throw ServerLLMStubError.notConfigured
    }

    func generateScenarioMessage(scenario: ConversationScenario, context: ConversationGenerationContext) async throws -> ChatMessage {
        throw ServerLLMStubError.notConfigured
    }

    func generateMomentMessage(context: MomentGenerationContext) async throws -> MomentMessage {
        throw ServerLLMStubError.notConfigured
    }

    enum ServerLLMStubError: Error {
        case notConfigured
    }
}
