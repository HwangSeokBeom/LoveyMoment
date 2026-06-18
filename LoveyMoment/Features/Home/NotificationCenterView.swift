import SwiftUI
import UserNotifications

/// 홈 알림 버튼이 여는 실제 동작 화면.
/// 권한 상태 확인 / 테스트 알림 / Moment 알림 관리 / 설정 열기를 제공한다.
struct NotificationCenterView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PoCTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        statusCard
                        actionsCard
                        todaysMessagesCard
                        enabledCharactersCard
                        if let status = store.testNotificationStatusText {
                            InlineNoticeView(text: status, icon: "timer.circle.fill")
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("알림 센터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                store.refreshNotificationAuthorizationStatus()
            }
        }
        .tint(.white)
    }

    private var statusCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "알림 권한")
                    Spacer()
                    TagPill(text: statusLabel, color: statusColor)
                }

                Text(statusDescription)
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
                    EmptyView()
                }
            }
        }
    }

    private var actionsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "알림 동작")

                SecondaryActionButton(title: "30초 뒤 캐릭터 메시지 받아보기", systemImage: "timer") {
                    store.scheduleTestCharacterNotification()
                }

                SecondaryActionButton(title: "Moment 알림 관리", systemImage: "moon.stars.fill") {
                    store.selectedTab = .moment
                    dismiss()
                }

                Text("캐릭터 메시지는 수면 리듬과 대화 흐름에 맞춰, 캐릭터가 직접 말을 거는 알림이에요.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var todaysMessagesCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "오늘 받을 캐릭터 메시지")

                if store.upcomingNotificationPlans.isEmpty {
                    Text("아직 예정된 메시지가 없어요. 아래에서 캐릭터의 알림을 켜면 자기 전·아침 메시지가 준비돼요.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.upcomingNotificationPlans) { plan in
                        planRow(plan)
                    }
                }
            }
        }
    }

    private func planRow(_ plan: CharacterNotificationPlan) -> some View {
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
                Text(plan.body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                Text("\(plan.scheduledDisplayText) · \(plan.source.userFacingLabel)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var enabledCharactersCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "알림 받는 캐릭터")

                ForEach(store.characters) { character in
                    HStack(spacing: 12) {
                        CharacterPortraitView(character: character, size: 40, style: .mini)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(character.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(character.stats.genreLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.isNotificationEnabled(for: character) },
                            set: { store.setNotificationEnabled($0, for: character) }
                        ))
                        .labelsHidden()
                        .tint(PoCTheme.primary)
                    }
                }
            }
        }
    }

    private var statusLabel: String {
        switch store.notificationAuthorizationStatus {
        case .authorized: return "허용됨"
        case .denied: return "거부됨"
        case .notDetermined: return "미설정"
        case .provisional: return "임시 허용"
        case .ephemeral: return "임시"
        @unknown default: return "확인 필요"
        }
    }

    private var statusColor: Color {
        store.notificationAuthorizationStatus == .authorized ? PoCTheme.secondary : PoCTheme.primary
    }

    private var statusDescription: String {
        switch store.notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "알림이 켜져 있어요. 잠들기 전·아침 Moment를 받을 수 있어요."
        case .notDetermined:
            return "아직 알림 권한을 설정하지 않았어요. 켜면 Moment 알림을 받을 수 있어요."
        case .denied:
            return "알림이 꺼져 있어요. 설정에서 허용하면 Moment 알림을 받을 수 있어요."
        @unknown default:
            return "알림 상태를 확인할 수 없어요."
        }
    }
}
