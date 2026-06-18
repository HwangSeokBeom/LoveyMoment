import SwiftUI

/// 분석된 관계 취향 프로필을 보여주고, 추천 예시로 넘어가는 화면.
struct DatingPreferenceProfileView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            if let profile = store.relationshipPreferenceProfile {
                content(profile)
            } else {
                emptyState
            }
        }
        .navigationTitle("나의 관계 취향")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ profile: RelationshipPreferenceProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard(profile)
                axesCard(profile)
                if !profile.keywordTags.isEmpty {
                    tagsCard(profile)
                }
                safetyNote
            }
            .padding(18)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryCTAButton(title: "어울리는 추천 예시 보기", systemImage: "person.2.fill") {
                store.loadDatingMatchCandidates()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            .background(PoCTheme.backgroundBottom.opacity(0.92).ignoresSafeArea(edges: .bottom))
        }
    }

    private func headerCard(_ profile: RelationshipPreferenceProfile) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SectionEyebrow(text: "취향 요약")
                Text(profile.headline)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(profile.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                if !profile.basedOnCharacterNames.isEmpty {
                    Text("분석한 대화: \(profile.basedOnCharacterNames.joined(separator: " · "))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func axesCard(_ profile: RelationshipPreferenceProfile) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(text: "관계 취향 4가지 결")
                ForEach(profile.axes) { axis in
                    axisRow(axis)
                }
            }
        }
    }

    private func axisRow(_ axis: RelationshipPreferenceAxis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(axis.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [PoCTheme.secondary, PoCTheme.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(10, geo.size.width * axis.normalizedValue), height: 8)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, geo.size.width * axis.normalizedValue - 7))
                }
            }
            .frame(height: 16)

            HStack {
                Text(axis.lowLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(axis.highLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(axis.tendencyText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tagsCard(_ profile: RelationshipPreferenceProfile) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "취향 키워드")
                FlexibleTagRow(tags: profile.keywordTags)
            }
        }
    }

    private var safetyNote: some View {
        InlineNoticeView(
            text: "이 결과는 취향 참고용이에요. 사람을 단정하거나 진단하지 않아요.",
            icon: "checkmark.shield.fill"
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.5))
            Text("아직 분석한 취향이 없어요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
