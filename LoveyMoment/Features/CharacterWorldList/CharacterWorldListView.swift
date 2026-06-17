import SwiftUI

struct CharacterWorldListView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    ForEach(store.characters) { character in
                        CharacterWorldCardView(
                            character: character,
                            world: store.world(for: character),
                            relationshipStage: store.relationshipStage(for: character),
                            lastSceneSummary: store.lastSceneSummary(for: character),
                            lastMessage: store.messages(for: character).last?.text ?? character.openingScene,
                            detailAction: { store.openDetail(for: character) },
                            chatAction: { store.startChat(with: character) }
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.refreshNotificationAuthorizationStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lovey Moment")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("잠들기 전 끊긴 장면을, 알림으로 다시 여는 캐릭터 월드")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: store.requestNotificationAuthorization) {
                    Image(systemName: "bell.badge.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PoCTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("알림 권한 요청")

                Button(action: store.openDiagnostics) {
                    Image(systemName: "stethoscope")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PoCTheme.secondary)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("PoC 진단 화면")
            }

            HStack(spacing: 8) {
                PoCBadgeView(title: nativeBadgeTitle)
                PoCBadgeView(title: store.currentSleepDiagnostics.source.displayName)
                PoCBadgeView(title: "Local Notification", color: PoCTheme.primary)
                PoCBadgeView(title: "iOS 26 SDK")
            }
        }
    }

    private var nativeBadgeTitle: String {
        let diagnostics = store.nativeLLMDiagnostics
        if diagnostics.lastGenerationSucceeded,
           diagnostics.lastGenerationMode == .nativeFoundationModel {
            return "Native LLM verified"
        }
        if store.nativeLLMAvailability.isAvailable {
            return "Native runtime ready"
        }
        return "Local fallback"
    }
}

struct CharacterWorldCardView: View {
    let character: CharacterProfile
    let world: WorldSetting
    let relationshipStage: RelationshipStage
    let lastSceneSummary: String
    let lastMessage: String
    let detailAction: () -> Void
    let chatAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    CharacterPortraitView(character: character, size: 142)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(character.name)
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.white)
                            Text(character.ageLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Text(character.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(character.stats.likesText + " likes · " + character.stats.creatorName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        TagPill(text: relationshipStage.label, color: PoCTheme.secondary)
                    }
                }

                FlowTags(tags: character.tags + [relationshipStage.progressHint])

                VStack(alignment: .leading, spacing: 10) {
                    InfoLine(title: "세계관", value: world.title)
                    InfoLine(title: "마지막 대화", value: lastMessage)
                    InfoLine(title: "Moment 가능성", value: "취침 \(character.sleepMomentSettings.isBedtimeMomentEnabled ? "ON" : "OFF") · 아침 \(character.sleepMomentSettings.isMorningMomentEnabled ? "ON" : "OFF") · \(lastSceneSummary)")
                }

                HStack(spacing: 10) {
                    SecondaryActionButton(title: "상세 보기", systemImage: "sparkles", action: detailAction)
                    Button(action: chatAction) {
                        Label("대화하기", systemImage: "message.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Color.black.opacity(0.82))
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(PoCTheme.primary)
                            )
                    }
                    .buttonStyle(.plain)
                }
        }
        .padding(16)
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

struct FlowTags: View {
    let tags: [String]

    var body: some View {
        FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
            TagPill(text: tag)
        }
    }
}

struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            VStack(alignment: alignment, spacing: spacing) {
                ForEach(computeRows(), id: \.self) { rowElements in
                    HStack(spacing: spacing) {
                        ForEach(rowElements, id: \.self) { element in
                            content(element)
                        }
                    }
                }
            }
        }
    }

    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRowWidth: CGFloat = 0

        for element in data {
            let estimatedWidth = CGFloat(String(describing: element).count * 12 + 28)
            if currentRowWidth + estimatedWidth + spacing > availableWidth, !rows[rows.count - 1].isEmpty {
                rows.append([element])
                currentRowWidth = estimatedWidth
            } else {
                rows[rows.count - 1].append(element)
                currentRowWidth += estimatedWidth + spacing
            }
        }

        return rows
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}
