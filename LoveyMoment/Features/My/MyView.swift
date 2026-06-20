import SwiftUI

/// MY 탭. 프로필, 알림 설정, 건강 앱 연결, AI 답장 품질 안내,
/// 앱 정보를 서비스 언어로 보여주고, 개발자 진단 화면으로 가는 입구를 둔다.
struct MyView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var isShowingNotificationCenter = false

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    notificationCard
                    healthCard
                    intelligenceCard
                    appInfoCard
                    diagnosticsEntry
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingNotificationCenter) {
            NotificationCenterView()
                .environmentObject(store)
        }
        .onAppear {
            store.refreshNotificationAuthorizationStatus()
        }
    }

    private var profileCard: some View {
        CardContainer {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(PoCTheme.primary.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(PoCTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("나의 Lovey")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("관심 캐릭터 \(store.characters.count)명과 이어지는 중")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
        }
    }

    private var notificationCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "알림 설정")
                    Spacer()
                    TagPill(text: notificationLabel, color: notificationColor)
                }

                Text("잠들기 전·아침 Moment 알림을 관리하고, 지금 바로 미리 받아 확인할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                SecondaryActionButton(title: "알림 센터 열기", systemImage: "bell.fill") {
                    isShowingNotificationCenter = true
                }
            }
        }
    }

    private var healthCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "건강 앱 연결")

                Text("건강 앱의 수면 기록을 연결하면, 실제 수면 리듬에 맞춰 Moment 시간을 맞춰드려요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if let message = store.healthConnectMessage {
                    InlineNoticeView(text: message, icon: "heart.text.square.fill")
                }

                PrimaryCTAButton(
                    title: store.isHealthConnecting ? "연결 중…" : "건강 앱 연결",
                    systemImage: "heart.fill",
                    isEnabled: !store.isHealthConnecting
                ) {
                    store.connectHealthKit()
                }
            }
        }
    }

    private var intelligenceCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "AI 답장 품질")
                    Spacer()
                    TagPill(text: intelligenceLabel, color: intelligenceColor)
                }

                Text(intelligenceDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appInfoCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "앱 정보")

                infoRow(title: "앱", value: "Lovey Moment")
                infoRow(title: "버전", value: appVersion)
                infoRow(title: "콘셉트", value: "잠들기 전 끊긴 장면을 다시 여는 캐릭터 월드")
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var diagnosticsEntry: some View {
        SecondaryActionButton(title: "개발자 진단 보기", systemImage: "wrench.and.screwdriver.fill") {
            store.openDiagnostics()
        }
    }

    // MARK: - Derived values

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

    private var intelligenceLabel: String {
        "캐릭터 맥락 반영"
    }

    private var intelligenceColor: Color {
        PoCTheme.secondary
    }

    private var intelligenceDescription: String {
        "PoC에서는 캐릭터 설정과 최근 대화 맥락을 바탕으로 답장을 만들고, 실제 서비스에서는 서버 AI 모델과 장기 메모리로 확장할 수 있어요."
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
