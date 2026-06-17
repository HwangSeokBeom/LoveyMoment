import SwiftUI

struct PoCBadgeView: View {
    let title: String
    var color: Color = PoCTheme.secondary

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.13))
                    .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
            )
    }
}

struct GeneratorDisclosureView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlexibleView(data: badgeTitles, spacing: 7, alignment: .leading) { title in
                PoCBadgeView(title: title, color: color(for: title))
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeTitles: [String] {
        if store.nativeLLMDiagnostics.lastGenerationSucceeded,
           store.nativeLLMDiagnostics.lastGenerationMode == .nativeFoundationModel {
            return ["Native LLM verified", "On-device", "No external API"]
        }
        if store.nativeLLMAvailability.isAvailable {
            return ["Native runtime available", "Awaiting success", "No external API"]
        }
        return ["Local Generator", "Fallback", "No external API"]
    }

    private var description: String {
        if store.nativeLLMDiagnostics.lastGenerationSucceeded,
           store.nativeLLMDiagnostics.lastGenerationMode == .nativeFoundationModel {
            return "마지막 생성이 Foundation Models 온디바이스 Native LLM으로 성공했습니다."
        }
        if store.nativeLLMAvailability.isAvailable {
            return "Foundation Models 런타임은 사용 가능하지만, 아직 앱 세션에서 Native generation 성공이 검증되지 않았습니다."
        }
        return "Foundation Models가 없거나 런타임에서 사용할 수 없어 외부 LLM API 없이 로컬 deterministic generator로 fallback 중입니다. 상태: \(store.nativeLLMAvailability.displayText)"
    }

    private func color(for title: String) -> Color {
        if title == "Native LLM verified" || title == "Local Generator" || title == "Fallback" {
            return PoCTheme.primary
        }
        return PoCTheme.secondary
    }
}
