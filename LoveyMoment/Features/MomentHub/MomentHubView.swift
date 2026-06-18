import SwiftUI

/// Moment 탭. 수면 리듬 기반 알림을 서비스 언어로 소개하고,
/// 캐릭터를 골라 잠들기 전 끊긴 장면을 다시 여는 흐름을 시작한다.
struct MomentHubView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    introCard
                    todaysMessagesCard
                    notificationStatusCard
                    characterPicker
                    if let status = store.testNotificationStatusText {
                        InlineNoticeView(text: status, icon: "timer.circle.fill")
                    }
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            store.refreshNotificationAuthorizationStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Moment")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.white)
            Text("잠들기 전 끊긴 장면을, 캐릭터가 다시 열어요")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var introCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "수면 리듬 기반 알림")

                Text("당신의 수면 리듬에 맞춰, 잠들기 전과 아침에 캐릭터가 마지막 장면을 다시 꺼내 말을 걸어요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    momentFeature(icon: "moon.stars.fill", title: "잠들기 전", subtitle: "끊긴 장면 이어가기")
                    momentFeature(icon: "sun.max.fill", title: "아침", subtitle: "다정한 첫 인사")
                }
            }
        }
    }

    private func momentFeature(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(PoCTheme.primary)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    @ViewBuilder
    private var todaysMessagesCard: some View {
        if !store.upcomingNotificationPlans.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(text: "오늘 받을 캐릭터 메시지")

                    ForEach(store.upcomingNotificationPlans.prefix(4)) { plan in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: plan.type.iconName)
                                .foregroundStyle(PoCTheme.primary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(plan.characterName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(plan.type.userFacingLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(PoCTheme.primary)
                                }
                                Text("\(plan.scheduledDisplayText) · \(plan.source.userFacingLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var notificationStatusCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "알림 상태")
                    Spacer()
                    TagPill(text: notificationLabel, color: notificationColor)
                }

                Text(notificationDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)

                switch store.notificationAuthorizationStatus {
                case .notDetermined:
                    PrimaryCTAButton(title: "알림 켜기", systemImage: "bell.fill") {
                        store.requestNotificationAuthorization()
                    }
                case .denied:
                    PrimaryCTAButton(title: "설정에서 알림 허용", systemImage: "gearshape.fill") {
                        store.openSystemNotificationSettings()
                    }
                default:
                    SecondaryActionButton(title: "30초 뒤 캐릭터 메시지 받아보기", systemImage: "timer") {
                        store.scheduleTestCharacterNotification()
                    }
                }
            }
        }
    }

    private var characterPicker: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "Moment 열 캐릭터 고르기")

                Text("캐릭터를 고르면 마지막 장면을 분석해 잠들기 전·아침 Moment를 준비해요.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(store.characters) { character in
                    Button {
                        store.startMomentAnalysis(for: character)
                    } label: {
                        momentCharacterRow(character)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isAnalyzing)
                }
            }
        }
    }

    private func momentCharacterRow(_ character: CharacterProfile) -> some View {
        HStack(spacing: 14) {
            CharacterPortraitView(character: character, size: 54, style: .mini)

            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(character.sleepMomentSettings.isBedtimeMomentEnabled
                     ? "오늘 밤 Moment 가능"
                     : "Moment 설정에서 켤 수 있어요")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if store.isAnalyzing && store.selectedCharacter?.id == character.id {
                ProgressView()
                    .tint(PoCTheme.primary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var notificationLabel: String {
        switch store.notificationAuthorizationStatus {
        case .authorized: return "켜짐"
        case .denied: return "꺼짐"
        case .notDetermined: return "미설정"
        case .provisional, .ephemeral: return "임시 허용"
        @unknown default: return "확인 필요"
        }
    }

    private var notificationColor: Color {
        store.notificationAuthorizationStatus == .authorized ? PoCTheme.secondary : PoCTheme.primary
    }

    private var notificationDescription: String {
        switch store.notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "알림이 켜져 있어요. 잠들기 전·아침 Moment를 받을 수 있어요."
        case .notDetermined:
            return "알림을 켜면 수면 리듬에 맞춰 Moment를 받을 수 있어요."
        case .denied:
            return "알림이 꺼져 있어요. 설정에서 허용하면 Moment를 받을 수 있어요."
        @unknown default:
            return "알림 상태를 확인할 수 없어요."
        }
    }
}
