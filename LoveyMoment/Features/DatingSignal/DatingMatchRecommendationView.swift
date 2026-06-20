import SwiftUI

/// 취향 프로필에 어울리는 추천 "예시" 후보를 보여주는 화면.
struct DatingMatchRecommendationView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    @State private var tagSheet: TagSheetPayload?

    private let topAnchor = "dating-top"

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear.frame(height: 0).id(topAnchor)
                        header
                        exampleNotice
                        ForEach(store.datingMatchCandidates) { candidate in
                            Button {
                                store.openCandidateDetail(candidate)
                            } label: {
                                candidateCard(candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 140)
                }
                .refreshable { await store.refreshDatingRecommendations() }
                .onChange(of: store.datingScrollToTopToken) { _, _ in
                    withAnimation { proxy.scrollTo(topAnchor, anchor: .top) }
                }
            }
        }
        .navigationTitle("추천 예시")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $tagSheet) { payload in
            TagCloudSheet(payload: payload)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("이런 결의 사람과 잘 맞을 수 있어요")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture { store.datingScrollToTopToken += 1 }
            if let headline = store.relationshipPreferenceProfile?.headline {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var exampleNotice: some View {
        InlineNoticeView(
            text: "아래 프로필은 실제 인물이 아닌 예시예요. 추천 가능성만 보여줘요.",
            icon: "info.circle.fill"
        )
    }

    private func candidateCard(_ candidate: DatingMatchCandidate) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    DatingCandidateAvatarView(
                        gradientKey: candidate.gradientKey,
                        initials: candidate.initials,
                        size: 56
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(candidate.displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(candidate.ageLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Text(candidate.oneLine)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.4))
                }

                HStack(spacing: 8) {
                    TagPill(text: candidate.affinityLabel, color: PoCTheme.primary)
                    Text("예시 프로필")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                if !candidate.vibeTags.isEmpty {
                    CompactTagRow(tags: candidate.vibeTags, maxVisible: 2) {
                        tagSheet = TagSheetPayload(title: "전체 키워드", tags: candidate.vibeTags)
                    }
                }
            }
        }
        // 어떤 자식도 카드 밖으로 그려지지 못하도록 카드 모양으로 잘라낸다(이중 안전장치).
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
