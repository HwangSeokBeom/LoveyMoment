import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            MainTabView()

            if isShowingSplash {
                AppSplashView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        isShowingSplash = false
                    }
                    store.bootstrapAppSession()
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loveyMomentNotificationTapped)) { notification in
            store.handleNotificationPayload(notification.userInfo ?? [:])
        }
        .onChange(of: store.pendingNotificationRoute?.id) { _, _ in
            store.consumePendingNotificationRoute()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                store.handleAppDidEnterBackground()
            }
        }
    }
}

enum AppRoute: Hashable {
    case characterDetail(UUID)
    case chat
    case momentAnalysis
    case momentPreview
    case diagnostics
    case datingSignalIntro
    case datingSignalSelection
    case datingSignalAnalysis
    case datingSignalProfile
    case datingSignalRecommendations
    case datingSignalCandidateDetail(UUID)
}
