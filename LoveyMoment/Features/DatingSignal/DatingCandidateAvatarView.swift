import SwiftUI

/// 예시 추천 프로필용 추상 아바타. 실제 인물 사진을 쓰지 않고
/// gradientKey에 따른 그라데이션 + 이니셜로만 표현한다.
struct DatingCandidateAvatarView: View {
    let gradientKey: String
    let initials: String
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    private var gradient: LinearGradient {
        let colors: [Color]
        switch gradientKey {
        case "dusk":
            colors = [Color(red: 0.36, green: 0.30, blue: 0.55), Color(red: 0.62, green: 0.42, blue: 0.66)]
        case "coral":
            colors = [Color(red: 0.95, green: 0.50, blue: 0.52), Color(red: 0.98, green: 0.72, blue: 0.55)]
        case "midnight":
            colors = [Color(red: 0.16, green: 0.20, blue: 0.38), Color(red: 0.30, green: 0.26, blue: 0.50)]
        case "violet":
            colors = [Color(red: 0.45, green: 0.32, blue: 0.66), Color(red: 0.72, green: 0.48, blue: 0.80)]
        case "honey":
            colors = [Color(red: 0.92, green: 0.66, blue: 0.40), Color(red: 0.96, green: 0.82, blue: 0.58)]
        default:
            colors = [PoCTheme.primary.opacity(0.7), PoCTheme.secondary.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
