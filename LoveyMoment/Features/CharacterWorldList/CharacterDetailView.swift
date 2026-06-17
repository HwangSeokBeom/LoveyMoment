import SwiftUI

struct CharacterDetailView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var selectedTab: CharacterDetailTab = .opening

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            if let character = store.selectedCharacter {
                content(for: character)
            } else {
                ContentUnavailableView("캐릭터를 찾을 수 없어요", systemImage: "questionmark.circle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Image(systemName: "square.and.arrow.up")
                Image(systemName: "ellipsis")
            }
        }
    }

    private func content(for character: CharacterProfile) -> some View {
        let world = store.world(for: character)
        let stage = store.relationshipStage(for: character)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero(character: character, world: world, stage: stage)
                tabBar
                tabContent(character: character, world: world, stage: stage)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                PrimaryCTAButton(title: "대화하기", systemImage: "message.fill") {
                    store.startChat(with: character)
                }
            }
            .padding(18)
            .background(.ultraThinMaterial.opacity(0.62))
        }
    }

    private func hero(character: CharacterProfile, world: WorldSetting, stage: RelationshipStage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                CharacterPortraitView(character: character, size: 294)
                    .frame(maxWidth: .infinity)

                LinearGradient(
                    colors: [.clear, PoCTheme.card.opacity(0.90)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 136)
                .frame(maxHeight: .infinity, alignment: .bottom)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(character.name)
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(.white)
                        Text(character.ageLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Text(character.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    FlowTags(tags: character.tags)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 10) {
                StatChip(title: "좋아요", value: character.stats.likesText)
                StatChip(title: "타입", value: character.stats.characterType)
                StatChip(title: "관계", value: stage.progressHint)
            }

            InlineNoticeView(text: world.summary, icon: "sparkles")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PoCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PoCTheme.stroke))
        )
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(CharacterDetailTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedTab == tab ? Color.black.opacity(0.82) : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? PoCTheme.primary : Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func tabContent(character: CharacterProfile, world: WorldSetting, stage: RelationshipStage) -> some View {
        switch selectedTab {
        case .opening:
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(text: "첫 장면")
                    Text(character.openingScene)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                    InfoLine(title: "마지막 장면", value: store.lastSceneSummary(for: character))
                }
            }
        case .story:
            CardContainer {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(text: "서사")
                    AnalysisResultRowView(title: "프로필", value: character.personalitySummary, icon: "person.text.rectangle.fill")
                    AnalysisResultRowView(title: "관계 단계", value: "\(stage.label) → \(stage.progressHint)\n\(stage.description)", icon: "arrow.up.heart.fill")
                    AnalysisResultRowView(title: "세계관 규칙", value: world.relationshipRules, icon: "map.fill")
                    AnalysisResultRowView(title: "스토리 수", value: "\(character.stats.storyCount)개 에피소드 · \(store.seedSnapshots(for: character).count)개 검증용 스냅샷", icon: "books.vertical.fill")
                }
            }
        case .news:
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(text: "소식")
                    Text(character.creatorNote)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                    InlineNoticeView(text: character.stats.updateNote, icon: "megaphone.fill")
                    Text("creator · \(character.stats.creatorName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
        case .community:
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(text: "커뮤니티")
                    CommunityRow(title: "오늘 Moment 문구 너무 캐릭터 같아요", message: "잠들기 전에 온 알림이 마지막 장면이랑 이어져서 몰입감 좋았어요.")
                    CommunityRow(title: "\(character.name) 루트 다음 업데이트 기대 중", message: "\(character.stats.communityPosts)개의 팬 반응이 쌓였어요.")
                }
            }
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

private struct CommunityRow: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private enum CharacterDetailTab: String, CaseIterable, Identifiable {
    case opening
    case story
    case news
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opening: return "첫 장면"
        case .story: return "서사"
        case .news: return "소식"
        case .community: return "커뮤니티"
        }
    }
}
