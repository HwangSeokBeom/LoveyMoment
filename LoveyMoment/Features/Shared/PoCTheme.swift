import SwiftUI

enum PoCTheme {
    static let backgroundTop = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let backgroundBottom = Color(red: 0.16, green: 0.10, blue: 0.18)
    static let card = Color.white.opacity(0.09)
    static let cardStrong = Color.white.opacity(0.14)
    static let stroke = Color.white.opacity(0.16)
    static let primary = Color(red: 1.00, green: 0.73, blue: 0.80)
    static let secondary = Color(red: 0.75, green: 0.82, blue: 1.00)
    static let userBubble = Color(red: 0.32, green: 0.39, blue: 0.58)
    static let characterBubble = Color(red: 0.31, green: 0.18, blue: 0.25)

    static var background: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PoCTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PoCTheme.stroke, lineWidth: 1)
                    )
            )
    }
}

struct PrimaryCTAButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isEnabled ? PoCTheme.primary : Color.white.opacity(0.12))
                )
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PoCTheme.stroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct TagPill: View {
    let text: String
    var color: Color = PoCTheme.secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
                    .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
            )
    }
}

struct SectionEyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(PoCTheme.primary)
            .tracking(0.4)
    }
}

struct InlineNoticeView: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PoCTheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PoCTheme.primary.opacity(0.12))
            )
    }
}
