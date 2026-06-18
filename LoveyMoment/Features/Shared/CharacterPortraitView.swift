import SwiftUI
import UIKit

enum CharacterPortraitStyle {
    case mini
    case card
    case hero
    case message
}

/// 정사각형 portrait. 실제 생성 이미지 asset이 있으면 우선 표시하고,
/// asset이 없을 때만 procedural portrait로 fallback한다.
struct CharacterPortraitView: View {
    let character: CharacterProfile
    var size: CGFloat = 120
    var style: CharacterPortraitStyle = .card

    private var cornerRadius: CGFloat {
        switch style {
        case .message: return size * 0.5
        case .mini: return max(10, size * 0.26)
        case .card, .hero: return max(10, size * 0.12)
        }
    }

    private var hasAsset: Bool {
        UIImage(named: character.portraitAssetName) != nil
    }

    var body: some View {
        PortraitFillContent(character: character)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: size * 0.12, y: size * 0.06)
            .onAppear {
                print("[CharacterPortrait] asset=\(character.portraitAssetName) found=\(hasAsset) style=\(style)")
            }
    }
}

/// 상세 화면 hero 영역용. 실제 이미지를 가로 가득 채우고 얼굴이 잘 보이도록 상단 정렬한다.
struct CharacterHeroPortraitView: View {
    let character: CharacterProfile
    var height: CGFloat = 380

    private var hasAsset: Bool {
        UIImage(named: character.portraitAssetName) != nil
    }

    var body: some View {
        PortraitFillContent(character: character, verticalAlignment: .top)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .onAppear {
                print("[CharacterPortrait] asset=\(character.portraitAssetName) found=\(hasAsset) style=hero")
            }
    }
}

/// 실제 asset 이미지를 채워 그리거나, asset이 없으면 procedural portrait를 그린다.
private struct PortraitFillContent: View {
    let character: CharacterProfile
    var verticalAlignment: VerticalAlignment = .center

    var body: some View {
        if let uiImage = UIImage(named: character.portraitAssetName) {
            Color.clear.overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment),
                alignment: alignment
            )
            .clipped()
        } else {
            ProceduralPortraitContent(character: character)
                .onAppear {
                    print("[CharacterPortrait] asset=\(character.portraitAssetName) missing fallback=procedural")
                }
        }
    }

    private var alignment: Alignment {
        switch verticalAlignment {
        case .top: return .top
        case .bottom: return .bottom
        default: return .center
        }
    }
}

/// 기존 SwiftUI 도형 기반 portrait. asset이 없을 때만 사용되는 최종 fallback.
private struct ProceduralPortraitContent: View {
    let character: CharacterProfile

    private var palette: CharacterPortraitPalette {
        CharacterPortraitPalette.palette(for: character.generatedAvatarKey)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                BackgroundLayer(size: size, palette: palette)
                BodyLayer(size: size, palette: palette)
                HeadLayer(size: size, palette: palette)
                HairLayer(size: size, palette: palette)
                ExpressionLayer(size: size, palette: palette)
                OutfitLayer(size: size, palette: palette)
                PolishLayer(size: size, palette: palette)
            }
            .frame(width: size, height: size)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct BackgroundLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [palette.rimLight.opacity(0.55), .clear],
                center: palette.lightCenter,
                startRadius: 4,
                endRadius: size * 0.72
            )

            diagonalLight

            LinearGradient(
                colors: [.black.opacity(0.34), .clear, .black.opacity(0.36)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var diagonalLight: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.16), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size * 0.26, height: size * 1.35)
            .rotationEffect(.degrees(-24))
            .offset(x: -size * 0.20, y: -size * 0.04)
            .blur(radius: size * 0.02)
    }
}

private struct BodyLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.30))
                .frame(width: size * 0.76, height: size * 0.18)
                .offset(y: size * 0.42)

            shoulderShape
                .fill(
                    LinearGradient(
                        colors: [palette.outfit.lighter(by: 0.04), palette.outfit, palette.outfit.darker(by: 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.24), radius: size * 0.04, y: size * 0.02)

            collarShadow
        }
    }

    private var shoulderShape: Path {
        Path { path in
            path.move(to: CGPoint(x: size * 0.08, y: size * 0.88))
            path.addCurve(
                to: CGPoint(x: size * 0.34, y: size * 0.58),
                control1: CGPoint(x: size * 0.11, y: size * 0.70),
                control2: CGPoint(x: size * 0.21, y: size * 0.62)
            )
            path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.58))
            path.addCurve(
                to: CGPoint(x: size * 0.92, y: size * 0.88),
                control1: CGPoint(x: size * 0.79, y: size * 0.62),
                control2: CGPoint(x: size * 0.89, y: size * 0.70)
            )
            path.closeSubpath()
        }
    }

    private var collarShadow: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.34, y: size * 0.58))
            path.addQuadCurve(
                to: CGPoint(x: size * 0.66, y: size * 0.58),
                control: CGPoint(x: size * 0.50, y: size * 0.67)
            )
            path.addLine(to: CGPoint(x: size * 0.61, y: size * 0.73))
            path.addQuadCurve(
                to: CGPoint(x: size * 0.39, y: size * 0.73),
                control: CGPoint(x: size * 0.50, y: size * 0.80)
            )
            path.closeSubpath()
        }
        .fill(.black.opacity(0.18))
    }
}

private struct HeadLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            neck
            ears
            face
            jawShadow
            nose
            mouth
        }
    }

    private var neck: some View {
        RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [palette.skin, palette.skin.darker(by: 0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.18, height: size * 0.25)
            .offset(y: size * 0.22)
    }

    private var ears: some View {
        HStack(spacing: size * 0.36) {
            ear
            ear
        }
        .offset(y: -size * 0.02)
    }

    private var ear: some View {
        Capsule()
            .fill(palette.skin.darker(by: 0.05))
            .frame(width: size * 0.060, height: size * 0.112)
            .overlay(
                Capsule()
                    .stroke(palette.skin.darker(by: 0.14), lineWidth: max(0.6, size * 0.006))
                    .opacity(0.50)
            )
    }

    private var face: some View {
        faceShape
            .fill(
                LinearGradient(
                    colors: [palette.skin.lighter(by: 0.08), palette.skin, palette.skin.darker(by: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .black.opacity(0.18), radius: size * 0.018, y: size * 0.012)
            .overlay(
                faceShape
                    .stroke(.white.opacity(0.12), lineWidth: max(0.5, size * 0.004))
            )
    }

    private var faceShape: Path {
        Path { path in
            path.move(to: CGPoint(x: size * 0.36, y: size * 0.24))
            path.addCurve(
                to: CGPoint(x: size * 0.64, y: size * 0.24),
                control1: CGPoint(x: size * 0.41, y: size * 0.15),
                control2: CGPoint(x: size * 0.59, y: size * 0.15)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.67, y: size * 0.48),
                control1: CGPoint(x: size * 0.69, y: size * 0.31),
                control2: CGPoint(x: size * 0.69, y: size * 0.41)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.50, y: size * 0.66),
                control1: CGPoint(x: size * 0.64, y: size * 0.57),
                control2: CGPoint(x: size * 0.57, y: size * 0.64)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.33, y: size * 0.48),
                control1: CGPoint(x: size * 0.43, y: size * 0.64),
                control2: CGPoint(x: size * 0.36, y: size * 0.57)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.36, y: size * 0.24),
                control1: CGPoint(x: size * 0.31, y: size * 0.41),
                control2: CGPoint(x: size * 0.31, y: size * 0.31)
            )
        }
    }

    private var jawShadow: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.39, y: size * 0.54))
            path.addQuadCurve(
                to: CGPoint(x: size * 0.61, y: size * 0.54),
                control: CGPoint(x: size * 0.50, y: size * 0.68)
            )
        }
        .stroke(palette.skin.darker(by: 0.16).opacity(0.42), lineWidth: max(0.7, size * 0.007))
    }

    private var nose: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.515, y: size * 0.395))
            path.addQuadCurve(
                to: CGPoint(x: size * 0.495, y: size * 0.475),
                control: CGPoint(x: size * 0.53, y: size * 0.445)
            )
        }
        .stroke(palette.skin.darker(by: 0.18).opacity(0.50), lineWidth: max(0.7, size * 0.007))
    }

    private var mouth: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.455, y: size * 0.555))
            path.addQuadCurve(
                to: CGPoint(x: size * 0.555, y: size * 0.555),
                control: CGPoint(x: size * (0.505 + palette.smileLift), y: size * 0.575)
            )
        }
        .stroke(palette.mouth.opacity(0.78), lineWidth: max(0.8, size * 0.008))
    }
}

private struct HairLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            backHair
            sideLocks
            crownMass
            frontLocks
            hairHighlights
        }
    }

    private var backHair: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.31, y: size * 0.30))
            path.addCurve(
                to: CGPoint(x: size * 0.69, y: size * 0.30),
                control1: CGPoint(x: size * 0.34, y: size * 0.08),
                control2: CGPoint(x: size * 0.66, y: size * 0.08)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.65, y: size * 0.60),
                control1: CGPoint(x: size * 0.77, y: size * 0.41),
                control2: CGPoint(x: size * 0.73, y: size * 0.55)
            )
            path.addQuadCurve(
                to: CGPoint(x: size * 0.35, y: size * 0.60),
                control: CGPoint(x: size * 0.50, y: size * 0.70)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.31, y: size * 0.30),
                control1: CGPoint(x: size * 0.27, y: size * 0.55),
                control2: CGPoint(x: size * 0.23, y: size * 0.41)
            )
        }
        .fill(
            LinearGradient(
                colors: [palette.hair.lighter(by: 0.08), palette.hair, palette.hair.darker(by: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var sideLocks: some View {
        ZStack {
            sideLock(isLeft: true, length: palette.sideLockLength)
            sideLock(isLeft: false, length: palette.sideLockLength * (palette.hasLongBackHair ? 1.18 : 0.92))

            if palette.hasLongBackHair {
                sideLock(isLeft: true, length: 0.44)
                    .offset(x: -size * 0.035, y: size * 0.06)
                sideLock(isLeft: false, length: 0.48)
                    .offset(x: size * 0.035, y: size * 0.08)
            }
        }
    }

    private func sideLock(isLeft: Bool, length: CGFloat) -> some View {
        Path { path in
            let x = isLeft ? size * 0.34 : size * 0.66
            let direction: CGFloat = isLeft ? -1 : 1
            path.move(to: CGPoint(x: x, y: size * 0.25))
            path.addCurve(
                to: CGPoint(x: x + direction * size * 0.04, y: size * (0.25 + length)),
                control1: CGPoint(x: x + direction * size * 0.08, y: size * 0.35),
                control2: CGPoint(x: x + direction * size * 0.09, y: size * (0.20 + length))
            )
            path.addCurve(
                to: CGPoint(x: x - direction * size * 0.02, y: size * 0.30),
                control1: CGPoint(x: x + direction * size * 0.01, y: size * (0.24 + length)),
                control2: CGPoint(x: x - direction * size * 0.04, y: size * 0.39)
            )
            path.closeSubpath()
        }
        .fill(palette.hair.darker(by: isLeft ? 0.02 : 0.08))
    }

    private var crownMass: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.28, y: size * 0.30))
            path.addCurve(
                to: CGPoint(x: size * 0.72, y: size * 0.28),
                control1: CGPoint(x: size * 0.35, y: size * 0.10),
                control2: CGPoint(x: size * 0.61, y: size * 0.08)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.62, y: size * 0.36),
                control1: CGPoint(x: size * 0.73, y: size * 0.35),
                control2: CGPoint(x: size * 0.68, y: size * 0.38)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.33, y: size * 0.37),
                control1: CGPoint(x: size * 0.53, y: size * 0.31),
                control2: CGPoint(x: size * 0.43, y: size * 0.33)
            )
            path.addCurve(
                to: CGPoint(x: size * 0.28, y: size * 0.30),
                control1: CGPoint(x: size * 0.28, y: size * 0.39),
                control2: CGPoint(x: size * 0.25, y: size * 0.34)
            )
        }
        .fill(palette.hair)
    }

    private var frontLocks: some View {
        ZStack {
            ForEach(palette.frontLocks.indices, id: \.self) { index in
                let lock = palette.frontLocks[index]
                hairLock(lock)
            }
        }
    }

    private func hairLock(_ lock: HairLock) -> some View {
        Path { path in
            let root = CGPoint(x: size * lock.rootX, y: size * lock.rootY)
            let tip = CGPoint(x: size * lock.tipX, y: size * lock.tipY)
            path.move(to: root)
            path.addQuadCurve(
                to: tip,
                control: CGPoint(x: size * lock.controlX, y: size * lock.controlY)
            )
            path.addQuadCurve(
                to: CGPoint(x: root.x + size * lock.width, y: root.y + size * 0.015),
                control: CGPoint(x: size * (lock.controlX + lock.width * 0.7), y: size * (lock.controlY + 0.03))
            )
            path.closeSubpath()
        }
        .fill(lock.isHighlight ? palette.hair.lighter(by: 0.08) : palette.hair.darker(by: lock.darkness))
    }

    private var hairHighlights: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.10))
                    .frame(width: size * 0.11, height: size * 0.010)
                    .rotationEffect(.degrees(palette.hairAngle + Double(index) * 5))
                    .offset(x: size * (-0.07 + CGFloat(index) * 0.06), y: -size * (0.23 - CGFloat(index) * 0.025))
            }
        }
    }
}

private struct ExpressionLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            eye(isLeft: true)
            eye(isLeft: false)
            brow(isLeft: true)
            brow(isLeft: false)
        }
    }

    private func eye(isLeft: Bool) -> some View {
        Path { path in
            let x0 = size * (isLeft ? 0.405 : 0.535)
            let x1 = size * (isLeft ? 0.475 : 0.605)
            let y = size * (0.410 + palette.eyeYOffset)
            let lift = size * palette.eyeLift * (isLeft ? -1 : 1)
            path.move(to: CGPoint(x: x0, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x1, y: y + lift),
                control: CGPoint(x: (x0 + x1) * 0.5, y: y - size * palette.eyeCurve)
            )
        }
        .stroke(palette.eye, style: StrokeStyle(lineWidth: max(1.2, size * 0.012), lineCap: .round))
        .overlay(
            Circle()
                .fill(.white.opacity(0.36))
                .frame(width: size * 0.018, height: size * 0.018)
                .offset(x: size * (isLeft ? -0.055 : 0.075), y: size * (0.006 + palette.eyeYOffset))
        )
    }

    private func brow(isLeft: Bool) -> some View {
        Capsule()
            .fill(palette.hair.darker(by: 0.10))
            .frame(width: size * 0.09, height: max(1.2, size * 0.012))
            .rotationEffect(.degrees((isLeft ? -1 : 1) * palette.browTilt))
            .offset(x: size * (isLeft ? -0.07 : 0.07), y: -size * 0.12)
    }
}

private struct OutfitLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            shirt
            lapels
            accentDetail
            highCollar
        }
    }

    private var shirt: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.42, y: size * 0.60))
            path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.60))
            path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.90))
            path.addLine(to: CGPoint(x: size * 0.38, y: size * 0.90))
            path.closeSubpath()
        }
        .fill(palette.shirt.opacity(palette.shirtOpacity))
    }

    private var lapels: some View {
        ZStack {
            lapel(isLeft: true)
            lapel(isLeft: false)
        }
    }

    private func lapel(isLeft: Bool) -> some View {
        Path { path in
            if isLeft {
                path.move(to: CGPoint(x: size * 0.30, y: size * 0.61))
                path.addLine(to: CGPoint(x: size * 0.47, y: size * 0.66))
                path.addLine(to: CGPoint(x: size * 0.39, y: size * 0.89))
                path.addLine(to: CGPoint(x: size * 0.25, y: size * 0.86))
            } else {
                path.move(to: CGPoint(x: size * 0.70, y: size * 0.61))
                path.addLine(to: CGPoint(x: size * 0.53, y: size * 0.66))
                path.addLine(to: CGPoint(x: size * 0.61, y: size * 0.89))
                path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.86))
            }
            path.closeSubpath()
        }
        .fill(palette.lapel)
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: size * (isLeft ? 0.47 : 0.53), y: size * 0.66))
                path.addLine(to: CGPoint(x: size * (isLeft ? 0.39 : 0.61), y: size * 0.89))
            }
            .stroke(.white.opacity(0.12), lineWidth: max(0.6, size * 0.006))
        )
    }

    @ViewBuilder
    private var accentDetail: some View {
        switch palette.outfitKind {
        case .tie:
            Path { path in
                path.move(to: CGPoint(x: size * 0.50, y: size * 0.63))
                path.addLine(to: CGPoint(x: size * 0.55, y: size * 0.72))
                path.addLine(to: CGPoint(x: size * 0.51, y: size * 0.90))
                path.addLine(to: CGPoint(x: size * 0.46, y: size * 0.72))
                path.closeSubpath()
            }
            .fill(palette.accent)
        case .knit:
            VStack(spacing: size * 0.028) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(.white.opacity(0.10))
                        .frame(width: size * 0.30, height: max(0.8, size * 0.006))
                }
            }
            .offset(y: size * 0.25)
        case .hood:
            Path { path in
                path.move(to: CGPoint(x: size * 0.28, y: size * 0.62))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.72, y: size * 0.62),
                    control: CGPoint(x: size * 0.50, y: size * 0.80)
                )
                path.addLine(to: CGPoint(x: size * 0.65, y: size * 0.76))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.35, y: size * 0.76),
                    control: CGPoint(x: size * 0.50, y: size * 0.66)
                )
                path.closeSubpath()
            }
            .fill(palette.accent.opacity(0.48))
        case .gothic:
            EmptyView()
        }
    }

    @ViewBuilder
    private var highCollar: some View {
        if palette.outfitKind == .gothic {
            ZStack {
                collarWing(isLeft: true)
                collarWing(isLeft: false)
                Capsule()
                    .fill(palette.accent.opacity(0.78))
                    .frame(width: size * 0.08, height: size * 0.24)
                    .offset(y: size * 0.25)
            }
        }
    }

    private func collarWing(isLeft: Bool) -> some View {
        Path { path in
            if isLeft {
                path.move(to: CGPoint(x: size * 0.33, y: size * 0.61))
                path.addLine(to: CGPoint(x: size * 0.46, y: size * 0.56))
                path.addLine(to: CGPoint(x: size * 0.43, y: size * 0.80))
                path.addLine(to: CGPoint(x: size * 0.29, y: size * 0.82))
            } else {
                path.move(to: CGPoint(x: size * 0.67, y: size * 0.61))
                path.addLine(to: CGPoint(x: size * 0.54, y: size * 0.56))
                path.addLine(to: CGPoint(x: size * 0.57, y: size * 0.80))
                path.addLine(to: CGPoint(x: size * 0.71, y: size * 0.82))
            }
            path.closeSubpath()
        }
        .fill(palette.lapel.darker(by: 0.04))
    }
}

private struct PolishLayer: View {
    let size: CGFloat
    let palette: CharacterPortraitPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(8, size * 0.08), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear, .black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.softLight)

            Rectangle()
                .fill(palette.rimLight.opacity(0.22))
                .frame(width: size * 0.025)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .blur(radius: size * 0.010)

            VStack(spacing: size * 0.030) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.018 : 0.010))
                        .frame(height: max(0.35, size * 0.002))
                }
            }
            .rotationEffect(.degrees(-12))
            .opacity(0.7)
        }
        .allowsHitTesting(false)
    }
}

private struct CharacterPortraitPalette {
    let background: [Color]
    let skin: Color
    let hair: Color
    let eye: Color
    let mouth: Color
    let outfit: Color
    let lapel: Color
    let shirt: Color
    let accent: Color
    let rimLight: Color
    let lightCenter: UnitPoint
    let hairAngle: Double
    let browTilt: Double
    let eyeCurve: CGFloat
    let eyeLift: CGFloat
    let eyeYOffset: CGFloat
    let smileLift: CGFloat
    let sideLockLength: CGFloat
    let shirtOpacity: Double
    let hasLongBackHair: Bool
    let outfitKind: OutfitKind
    let frontLocks: [HairLock]

    static func palette(for key: String) -> CharacterPortraitPalette {
        switch key {
        case "ice-boss":
            return CharacterPortraitPalette(
                background: [Color(red: 0.06, green: 0.08, blue: 0.15), Color(red: 0.24, green: 0.13, blue: 0.26), Color(red: 0.74, green: 0.25, blue: 0.50)],
                skin: Color(red: 0.93, green: 0.77, blue: 0.68),
                hair: Color(red: 0.055, green: 0.065, blue: 0.095),
                eye: Color(red: 0.13, green: 0.16, blue: 0.25),
                mouth: Color(red: 0.42, green: 0.16, blue: 0.20),
                outfit: Color(red: 0.07, green: 0.10, blue: 0.18),
                lapel: Color(red: 0.16, green: 0.19, blue: 0.31),
                shirt: .white,
                accent: Color(red: 0.88, green: 0.25, blue: 0.52),
                rimLight: Color(red: 1.0, green: 0.47, blue: 0.76),
                lightCenter: .topTrailing,
                hairAngle: -7,
                browTilt: 12,
                eyeCurve: 0.012,
                eyeLift: -0.016,
                eyeYOffset: -0.004,
                smileLift: -0.008,
                sideLockLength: 0.30,
                shirtOpacity: 0.92,
                hasLongBackHair: false,
                outfitKind: .tie,
                frontLocks: [
                    HairLock(rootX: 0.33, rootY: 0.27, controlX: 0.37, controlY: 0.38, tipX: 0.43, tipY: 0.43, width: 0.060, darkness: 0.03, isHighlight: false),
                    HairLock(rootX: 0.42, rootY: 0.22, controlX: 0.48, controlY: 0.34, tipX: 0.49, tipY: 0.47, width: 0.075, darkness: 0.00, isHighlight: true),
                    HairLock(rootX: 0.54, rootY: 0.22, controlX: 0.61, controlY: 0.33, tipX: 0.57, tipY: 0.42, width: 0.065, darkness: 0.08, isHighlight: false),
                    HairLock(rootX: 0.63, rootY: 0.27, controlX: 0.70, controlY: 0.37, tipX: 0.64, tipY: 0.48, width: 0.052, darkness: 0.12, isHighlight: false)
                ]
            )
        case "sunny-friend":
            return CharacterPortraitPalette(
                background: [Color(red: 0.10, green: 0.21, blue: 0.20), Color(red: 0.31, green: 0.55, blue: 0.48), Color(red: 0.93, green: 0.72, blue: 0.49)],
                skin: Color(red: 0.96, green: 0.78, blue: 0.63),
                hair: Color(red: 0.43, green: 0.25, blue: 0.15),
                eye: Color(red: 0.24, green: 0.18, blue: 0.13),
                mouth: Color(red: 0.54, green: 0.22, blue: 0.19),
                outfit: Color(red: 0.56, green: 0.51, blue: 0.39),
                lapel: Color(red: 0.78, green: 0.69, blue: 0.55),
                shirt: Color(red: 0.96, green: 0.91, blue: 0.82),
                accent: Color(red: 0.75, green: 0.94, blue: 0.82),
                rimLight: Color(red: 0.78, green: 1.0, blue: 0.87),
                lightCenter: .topLeading,
                hairAngle: 6,
                browTilt: 3,
                eyeCurve: 0.020,
                eyeLift: 0.004,
                eyeYOffset: 0.000,
                smileLift: 0.010,
                sideLockLength: 0.24,
                shirtOpacity: 0.86,
                hasLongBackHair: false,
                outfitKind: .knit,
                frontLocks: [
                    HairLock(rootX: 0.32, rootY: 0.29, controlX: 0.39, controlY: 0.34, tipX: 0.40, tipY: 0.42, width: 0.070, darkness: 0.03, isHighlight: false),
                    HairLock(rootX: 0.43, rootY: 0.22, controlX: 0.51, controlY: 0.30, tipX: 0.50, tipY: 0.40, width: 0.080, darkness: 0.00, isHighlight: true),
                    HairLock(rootX: 0.55, rootY: 0.23, controlX: 0.63, controlY: 0.31, tipX: 0.61, tipY: 0.39, width: 0.070, darkness: 0.06, isHighlight: false)
                ]
            )
        case "puppy-junior":
            return CharacterPortraitPalette(
                background: [Color(red: 0.12, green: 0.15, blue: 0.29), Color(red: 0.48, green: 0.52, blue: 0.88), Color(red: 1.0, green: 0.55, blue: 0.64)],
                skin: Color(red: 0.98, green: 0.79, blue: 0.63),
                hair: Color(red: 0.66, green: 0.47, blue: 0.29),
                eye: Color(red: 0.24, green: 0.17, blue: 0.14),
                mouth: Color(red: 0.58, green: 0.24, blue: 0.19),
                outfit: Color(red: 0.34, green: 0.36, blue: 0.60),
                lapel: Color(red: 0.62, green: 0.69, blue: 0.93),
                shirt: Color(red: 0.88, green: 0.91, blue: 0.98),
                accent: Color(red: 1.0, green: 0.71, blue: 0.80),
                rimLight: Color(red: 0.75, green: 0.84, blue: 1.0),
                lightCenter: .topTrailing,
                hairAngle: 13,
                browTilt: -5,
                eyeCurve: 0.017,
                eyeLift: 0.010,
                eyeYOffset: 0.000,
                smileLift: 0.016,
                sideLockLength: 0.20,
                shirtOpacity: 0.55,
                hasLongBackHair: false,
                outfitKind: .hood,
                frontLocks: [
                    HairLock(rootX: 0.29, rootY: 0.30, controlX: 0.34, controlY: 0.24, tipX: 0.33, tipY: 0.18, width: 0.060, darkness: 0.03, isHighlight: true),
                    HairLock(rootX: 0.39, rootY: 0.23, controlX: 0.48, controlY: 0.30, tipX: 0.45, tipY: 0.43, width: 0.075, darkness: 0.00, isHighlight: false),
                    HairLock(rootX: 0.52, rootY: 0.21, controlX: 0.62, controlY: 0.27, tipX: 0.60, tipY: 0.38, width: 0.080, darkness: 0.07, isHighlight: true),
                    HairLock(rootX: 0.67, rootY: 0.30, controlX: 0.78, controlY: 0.27, tipX: 0.76, tipY: 0.20, width: 0.050, darkness: 0.09, isHighlight: false)
                ]
            )
        case "nocturne-vampire":
            return CharacterPortraitPalette(
                background: [Color(red: 0.015, green: 0.015, blue: 0.035), Color(red: 0.17, green: 0.035, blue: 0.10), Color(red: 0.50, green: 0.025, blue: 0.14)],
                skin: Color(red: 0.86, green: 0.71, blue: 0.69),
                hair: Color(red: 0.10, green: 0.025, blue: 0.055),
                eye: Color(red: 0.63, green: 0.035, blue: 0.12),
                mouth: Color(red: 0.38, green: 0.04, blue: 0.09),
                outfit: Color(red: 0.030, green: 0.030, blue: 0.055),
                lapel: Color(red: 0.22, green: 0.035, blue: 0.085),
                shirt: Color(red: 0.86, green: 0.82, blue: 0.84),
                accent: Color(red: 0.78, green: 0.04, blue: 0.14),
                rimLight: Color(red: 1.0, green: 0.08, blue: 0.20),
                lightCenter: .trailing,
                hairAngle: -3,
                browTilt: 15,
                eyeCurve: 0.008,
                eyeLift: -0.018,
                eyeYOffset: -0.004,
                smileLift: -0.010,
                sideLockLength: 0.34,
                shirtOpacity: 0.62,
                hasLongBackHair: true,
                outfitKind: .gothic,
                frontLocks: [
                    HairLock(rootX: 0.31, rootY: 0.27, controlX: 0.37, controlY: 0.39, tipX: 0.40, tipY: 0.51, width: 0.065, darkness: 0.03, isHighlight: false),
                    HairLock(rootX: 0.44, rootY: 0.21, controlX: 0.52, controlY: 0.32, tipX: 0.50, tipY: 0.48, width: 0.080, darkness: 0.00, isHighlight: true),
                    HairLock(rootX: 0.56, rootY: 0.22, controlX: 0.66, controlY: 0.35, tipX: 0.62, tipY: 0.51, width: 0.060, darkness: 0.10, isHighlight: false)
                ]
            )
        default:
            return CharacterPortraitPalette(
                background: [PoCTheme.backgroundTop, PoCTheme.backgroundBottom],
                skin: Color(red: 0.93, green: 0.76, blue: 0.66),
                hair: Color(red: 0.18, green: 0.13, blue: 0.18),
                eye: Color(red: 0.2, green: 0.16, blue: 0.2),
                mouth: Color(red: 0.50, green: 0.20, blue: 0.22),
                outfit: PoCTheme.characterBubble,
                lapel: PoCTheme.cardStrong,
                shirt: .white,
                accent: PoCTheme.primary,
                rimLight: PoCTheme.primary,
                lightCenter: .topTrailing,
                hairAngle: 0,
                browTilt: 4,
                eyeCurve: 0.014,
                eyeLift: 0,
                eyeYOffset: 0,
                smileLift: 0,
                sideLockLength: 0.25,
                shirtOpacity: 0.80,
                hasLongBackHair: false,
                outfitKind: .tie,
                frontLocks: [
                    HairLock(rootX: 0.36, rootY: 0.26, controlX: 0.43, controlY: 0.35, tipX: 0.45, tipY: 0.42, width: 0.070, darkness: 0.03, isHighlight: false),
                    HairLock(rootX: 0.50, rootY: 0.22, controlX: 0.58, controlY: 0.33, tipX: 0.55, tipY: 0.43, width: 0.070, darkness: 0.05, isHighlight: true)
                ]
            )
        }
    }
}

private struct HairLock {
    let rootX: CGFloat
    let rootY: CGFloat
    let controlX: CGFloat
    let controlY: CGFloat
    let tipX: CGFloat
    let tipY: CGFloat
    let width: CGFloat
    let darkness: Double
    let isHighlight: Bool
}

private enum OutfitKind: Equatable {
    case tie
    case knit
    case hood
    case gothic
}

private extension Color {
    func lighter(by amount: Double) -> Color {
        adjusted(by: amount)
    }

    func darker(by amount: Double) -> Color {
        adjusted(by: -amount)
    }

    private func adjusted(by amount: Double) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(
            red: min(max(Double(red) + amount, 0), 1),
            green: min(max(Double(green) + amount, 0), 1),
            blue: min(max(Double(blue) + amount, 0), 1),
            opacity: Double(alpha)
        )
        #else
        return self
        #endif
    }
}
