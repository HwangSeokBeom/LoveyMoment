import SwiftUI
import UserNotifications

struct MomentPreviewView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if store.notificationAuthorizationStatus == .denied {
                        InlineNoticeView(text: "설정에서 알림을 허용하면 Moment 알림을 받을 수 있어요.", icon: "bell.slash.fill")
                    }

                    NotificationStatusCardView(
                        authorizationLabel: authorizationLabel,
                        lastScheduledNotificationID: store.lastScheduledNotificationID,
                        lastNotificationRoute: store.lastNotificationRoute
                    )

                    ForEach(store.momentCards()) { moment in
                        NotificationPreviewCardView(
                            moment: moment,
                            character: store.selectedCharacter,
                            toggle: Binding(
                                get: { moment.type == .bedtime ? store.momentSettings.isBedtimeMomentEnabled : store.momentSettings.isMorningMomentEnabled },
                                set: { value in
                                    if moment.type == .bedtime {
                                        store.updateBedtimeMomentEnabled(value)
                                    } else {
                                        store.updateMorningMomentEnabled(value)
                                    }
                                }
                            )
                        )
                    }

                    SecondaryActionButton(title: "10초 뒤 테스트 알림 예약", systemImage: "timer") {
                        store.scheduleTestNotification()
                    }

                    if let status = store.testNotificationStatusText {
                        InlineNoticeView(text: status, icon: "timer.circle.fill")
                    }

                    if let toast = store.toastMessage {
                        InlineNoticeView(text: toast, icon: "checkmark.circle.fill")
                    }

                    if !store.canContinueFromPreview {
                        InlineNoticeView(text: "Moment를 하나 이상 켜주세요.", icon: "exclamationmark.triangle.fill")
                    }
                }
                .padding(18)
                .padding(.bottom, 96)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimaryCTAButton(
                        title: "알림에서 채팅으로 이어보기",
                        systemImage: "arrowshape.turn.up.left.fill",
                        isEnabled: store.canContinueFromPreview,
                        action: store.continueFromMomentPreview
                    )
                }
                .padding(18)
                .background(.ultraThinMaterial.opacity(0.66))
            }
        }
        .navigationTitle("Moment 미리보기")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 14) {
                if let character = store.selectedCharacter {
                    CharacterAvatarView(character: character, size: 88, showsBadge: false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Moment 미리보기")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("토글은 실제 로컬 알림 예약/취소와 연결돼요. payload에는 characterId, momentId, momentType, deepLinkTarget이 포함됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        TagPill(text: authorizationLabel, color: PoCTheme.primary)
                        TagPill(text: "10초 테스트")
                    }
                }
            }
        }
        .onAppear {
            store.refreshNotificationAuthorizationStatus()
        }
    }

    private var authorizationLabel: String {
        switch store.notificationAuthorizationStatus {
        case .authorized: return "알림 허용됨"
        case .denied: return "알림 거부됨"
        case .notDetermined: return "권한 미요청"
        case .provisional: return "임시 허용"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "권한 확인 필요"
        }
    }
}

struct NotificationPreviewCardView: View {
    let moment: MomentMessage
    let character: CharacterProfile?
    @Binding var toggle: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TagPill(
                        text: moment.type.displayName,
                        color: moment.isEnabled ? PoCTheme.primary : Color.white.opacity(0.45)
                    )

                    Spacer()

                    Toggle("", isOn: $toggle)
                        .labelsHidden()
                        .tint(PoCTheme.primary)
                }

                HStack(alignment: .top, spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        if let character {
                            CharacterPortraitView(character: character, size: 58)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(moment.isEnabled ? PoCTheme.primary : Color.white.opacity(0.22))
                                .frame(width: 58, height: 58)
                        }

                        Image(systemName: moment.type == .morning ? "sun.max.fill" : "moon.stars.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(moment.isEnabled ? Color.black.opacity(0.78) : .white.opacity(0.55))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(moment.isEnabled ? PoCTheme.primary : Color.white.opacity(0.22)))
                            .offset(x: 4, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(moment.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)

                            Spacer(minLength: 8)

                            Text(moment.scheduledAt)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }

                        Text(moment.body)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(moment.isEnabled ? 0.88 : 0.42))
                            .fixedSize(horizontal: false, vertical: true)

                        if let generationMode = moment.generationMode {
                            TagPill(text: generationMode.badgeText, color: generationMode == .nativeFoundationModel ? PoCTheme.secondary : PoCTheme.primary)
                        }
                    }
                }
            }
        }
        .opacity(moment.isEnabled ? 1 : 0.58)
    }
}

private struct NotificationStatusCardView: View {
    let authorizationLabel: String
    let lastScheduledNotificationID: String?
    let lastNotificationRoute: AppNotificationRoute?

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "Local Notification")
                    Spacer()
                    TagPill(text: authorizationLabel, color: PoCTheme.primary)
                }

                AnalysisResultRowView(title: "마지막 예약 ID", value: lastScheduledNotificationID ?? "없음", icon: "timer")
                AnalysisResultRowView(title: "마지막 route", value: routeText, icon: "arrowshape.turn.up.left.fill")
                Text("APNs remote push는 서버, 인증서, key, device token backend가 필요하므로 이번 PoC 범위에서는 local notification 딥링크만 구현합니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var routeText: String {
        guard let route = lastNotificationRoute else { return "없음" }
        return "characterId=\(route.characterId.uuidString.prefix(8)) momentId=\(route.momentId.uuidString.prefix(8)) target=\(route.deepLinkTarget)"
    }
}
