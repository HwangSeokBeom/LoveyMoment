import SwiftUI

/// 추천 예시 후보 상세. 왜 어울릴 수 있는지와 안전 안내를 보여준다.
struct DatingMatchDetailView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            if let candidate = store.selectedDatingCandidate {
                content(candidate)
            } else {
                emptyState
            }
        }
        .navigationTitle("추천 예시")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ candidate: DatingMatchCandidate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileCard(candidate)
                reasonsCard(candidate)
                safetyCard
            }
            .padding(18)
        }
    }

    private func profileCard(_ candidate: DatingMatchCandidate) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    DatingCandidateAvatarView(
                        gradientKey: candidate.gradientKey,
                        initials: candidate.initials,
                        size: 72
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(candidate.displayName)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(.white)
                            Text(candidate.ageLabel)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        TagPill(text: candidate.affinityLabel, color: PoCTheme.primary)
                    }
                    Spacer(minLength: 0)
                }

                Text(candidate.oneLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(candidate.about)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if !candidate.vibeTags.isEmpty {
                    FlexibleTagRow(tags: candidate.vibeTags)
                }

                Label("실제 인물이 아닌 예시 프로필이에요.", systemImage: "info.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoCTheme.secondary)
            }
        }
    }

    private func reasonsCard(_ candidate: DatingMatchCandidate) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "내 취향과 닿는 점")
                ForEach(candidate.reasons) { reason in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(PoCTheme.primary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reason.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(reason.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var safetyCard: some View {
        let notice = DatingSafetyNotice.standard
        return CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Label(notice.title, systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PoCTheme.secondary)
                ForEach(notice.points, id: \.self) { point in
                    Text("· \(point)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.5))
            Text("프로필을 불러올 수 없어요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
