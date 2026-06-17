import SwiftUI

struct AppSplashView: View {
    let completion: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.06, blue: 0.12),
                    Color(red: 0.25, green: 0.10, blue: 0.20),
                    Color(red: 0.08, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [PoCTheme.primary.opacity(0.36), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(PoCTheme.primary.opacity(0.14))
                            .frame(width: 104, height: 104)
                            .blur(radius: 4)

                        Image(systemName: "bubble.left.and.heart.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(PoCTheme.primary)
                            .shadow(color: PoCTheme.primary.opacity(0.55), radius: 24)
                    }

                    Text("Lovey Moment")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Sleep-aware Character Moment PoC")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        SplashChip(text: "HealthKit fallback")
                        SplashChip(text: "Local Notification")
                    }

                    HStack(spacing: 8) {
                        SplashChip(text: "Local Conversation Generator")
                        SplashChip(text: "SwiftUI")
                        SplashChip(text: "iOS 17+")
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("PoC by 황석범")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("HealthKit + Notification + Local AI-like Conversation Flow")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.98)
            .animation(.easeOut(duration: 0.5), value: appeared)
        }
        .task {
            appeared = true
            try? await Task.sleep(for: .seconds(1.45))
            completion()
        }
    }
}

private struct SplashChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            )
    }
}
