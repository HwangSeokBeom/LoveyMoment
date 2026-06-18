import SwiftUI

/// 취향 분석을 시작하기 전, 어떻게 분석하고 무엇을 하지 않는지 동의받는 화면.
struct DatingSignalConsentView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    consentCard
                    noticeCard
                }
                .padding(18)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryCTAButton(
                title: "동의하고 대화 고르기",
                systemImage: "arrow.right",
                isEnabled: store.datingSignalConsent.isComplete
            ) {
                store.agreeDatingSignalConsent()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            .background(PoCTheme.backgroundBottom.opacity(0.92).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle("분석 동의")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("시작하기 전에 확인해주세요")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("Lovey Signal은 최애 캐릭터 대화에서 드러난 관계 취향만 분석해요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var consentCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                consentRow(
                    isOn: store.datingSignalConsent.agreesToConversationAnalysis,
                    title: "대화 기반 취향 분석에 동의해요",
                    detail: "내가 고른 캐릭터 대화의 분위기와 거리감을 분석에 사용해요."
                ) { store.setConsentConversationAnalysis($0) }

                Divider().overlay(PoCTheme.stroke)

                consentRow(
                    isOn: store.datingSignalConsent.agreesToExampleProfilesOnly,
                    title: "추천은 예시 프로필임을 이해했어요",
                    detail: "추천에 나오는 프로필은 모두 실제 인물이 아닌 예시예요."
                ) { store.setConsentExampleProfilesOnly($0) }

                Divider().overlay(PoCTheme.stroke)

                consentRow(
                    isOn: store.datingSignalConsent.agreesToNoRealMatching,
                    title: "실제 매칭·연락 기능이 없음을 알아요",
                    detail: "실제 만남·연락처 교환·결제·위치 공유는 제공하지 않아요."
                ) { store.setConsentNoRealMatching($0) }
            }
        }
    }

    private func consentRow(
        isOn: Bool,
        title: String,
        detail: String,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        Button {
            onChange(!isOn)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? PoCTheme.primary : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var noticeCard: some View {
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
}
