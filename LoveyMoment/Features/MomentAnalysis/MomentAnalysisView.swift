import SwiftUI

struct MomentAnalysisView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            if let analysis = store.currentAnalysis {
                analysisContent(analysis)
            } else {
                ContentUnavailableView("분석 결과가 없어요", systemImage: "sparkle.magnifyingglass")
            }
        }
        .navigationTitle("Lovey Moment 분석")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func analysisContent(_ analysis: MomentAnalysis) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(analysis)
                if let character = store.selectedCharacter {
                    analysisHero(character: character)
                }
                sleepCard(analysis.sleepSignal)
                analysisCard(analysis)
                MomentToggleSectionView(
                    bedtimeEnabled: Binding(
                        get: { store.momentSettings.isBedtimeMomentEnabled },
                        set: { store.updateBedtimeMomentEnabled($0) }
                    ),
                    morningEnabled: Binding(
                        get: { store.momentSettings.isMorningMomentEnabled },
                        set: { store.updateMorningMomentEnabled($0) }
                    )
                )
            }
            .padding(18)
            .padding(.bottom, 92)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                PrimaryCTAButton(
                    title: store.isScheduling ? "알림 예약 중" : "알림 미리보기",
                    systemImage: "bell.fill",
                    isEnabled: !store.isScheduling,
                    action: store.goToMomentPreview
                )
            }
            .padding(18)
            .background(.ultraThinMaterial.opacity(0.66))
        }
    }

    private func header(_ analysis: MomentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("분석 완료")
                .font(.title.weight(.heavy))
                .foregroundStyle(.white)

            Text("최근 \(store.currentSnapshot?.recentMessages.count ?? 0)개 메시지와 마지막 장면을 바탕으로 캐릭터별 Moment를 만들었어요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text("생성 시각 \(analysis.createdAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func analysisHero(character: CharacterProfile) -> some View {
        CardContainer {
            HStack(alignment: .center, spacing: 14) {
                CharacterAvatarView(character: character, size: 96, showsBadge: false)

                VStack(alignment: .leading, spacing: 10) {
                    Text(character.name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(character.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sleepCard(_ sleepSignal: SleepSignal) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "수면 리듬")
                    Spacer()
                    TagPill(text: sleepSignal.source == .healthKit ? "건강 앱 연결됨" : "기본 리듬", color: sleepSignal.source == .healthKit ? PoCTheme.secondary : PoCTheme.primary)
                }

                HStack(spacing: 10) {
                    SleepTimeChip(title: "취침 예상", time: sleepSignal.estimatedBedtime, icon: "moon.fill")
                    SleepTimeChip(title: "기상 예상", time: sleepSignal.estimatedWakeTime, icon: "sun.max.fill")
                }

                AnalysisResultRowView(title: "신뢰도", value: sleepSignal.confidence.rawValue.uppercased(), icon: "checkmark.seal.fill")

                Text(sleepSignal.explanation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func analysisCard(_ analysis: MomentAnalysis) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                SectionEyebrow(text: "Moment 분석 항목")
                AnalysisResultRowView(title: "세계관 분석", value: analysis.worldInsight, icon: "building.columns.fill")
                AnalysisResultRowView(title: "캐릭터 성격 분석", value: analysis.characterInsight, icon: "person.fill")
                AnalysisResultRowView(title: "관계 단계 분석", value: analysis.relationshipInsight, icon: "arrow.up.right.circle.fill")
                AnalysisResultRowView(title: "마지막 장면 분석", value: analysis.lastSceneInsight, icon: "film.stack.fill")
                AnalysisResultRowView(title: "감정선 분석", value: analysis.emotionInsight, icon: "heart.text.square.fill")
                AnalysisResultRowView(
                    title: "알림 톤 결정",
                    value: "\(analysis.toneDecision.toneLabel) · \(analysis.toneDecision.intensity)\n\(analysis.toneDecision.reason)\n키워드: \(analysis.toneDecision.styleKeywords.joined(separator: ", "))",
                    icon: "quote.bubble.fill"
                )
            }
        }
    }
}

struct SleepTimeChip: View {
    let title: String
    let time: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            Text(time)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PoCTheme.cardStrong)
        )
    }
}

struct AnalysisResultRowView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PoCTheme.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MomentToggleSectionView: View {
    @Binding var bedtimeEnabled: Bool
    @Binding var morningEnabled: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "Moment 설정")

                Toggle("자기 전 Moment", isOn: $bedtimeEnabled)
                    .tint(PoCTheme.primary)

                Divider().overlay(Color.white.opacity(0.12))

                Toggle("아침 Moment", isOn: $morningEnabled)
                    .tint(PoCTheme.primary)
            }
            .foregroundStyle(.white)
        }
    }
}
