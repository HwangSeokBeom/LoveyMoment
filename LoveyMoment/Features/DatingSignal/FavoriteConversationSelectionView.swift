import SwiftUI

/// 분석에 사용할 최애 캐릭터 대화를 2~3개 고르는 화면.
struct FavoriteConversationSelectionView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    selectionList
                }
                .padding(18)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Text(footerHint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                PrimaryCTAButton(
                    title: "이 대화로 취향 분석하기",
                    systemImage: "waveform.path.ecg",
                    isEnabled: store.canAnalyzeDatingPreference
                ) {
                    store.analyzeDatingPreference()
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            .background(PoCTheme.backgroundBottom.opacity(0.92).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle("대화 고르기")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("어떤 대화로 취향을 볼까요?")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("가장 나다웠던 대화를 2~3개 골라주세요. 고른 대화의 결을 모아 관계 취향을 그려드려요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectionList: some View {
        VStack(spacing: 12) {
            ForEach(store.signalConversationSelections) { selection in
                Button {
                    store.toggleSignalConversationSelection(selection)
                } label: {
                    selectionRow(selection)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectionRow(_ selection: FavoriteConversationSelection) -> some View {
        HStack(spacing: 14) {
            characterPortrait(selection)

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.characterName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(selection.lastSceneSummary.isEmpty
                     ? selection.genreLabel
                     : selection.lastSceneSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: selection.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selection.isSelected ? PoCTheme.primary : .white.opacity(0.35))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selection.isSelected ? PoCTheme.primary.opacity(0.12) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selection.isSelected ? PoCTheme.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func characterPortrait(_ selection: FavoriteConversationSelection) -> some View {
        if let character = store.characters.first(where: { $0.id == selection.characterId }) {
            CharacterPortraitView(character: character, size: 52, style: .mini)
        } else {
            DatingCandidateAvatarView(gradientKey: "dusk", initials: String(selection.characterName.prefix(1)), size: 52)
        }
    }

    private var footerHint: String {
        let count = store.selectedSignalConversationCount
        if count == 0 { return "대화를 2~3개 골라주세요." }
        if count == 1 { return "하나 더 고르면 분석할 수 있어요. (\(count)/3)" }
        return "\(count)개 선택됨 · 분석할 수 있어요. (\(count)/3)"
    }
}
