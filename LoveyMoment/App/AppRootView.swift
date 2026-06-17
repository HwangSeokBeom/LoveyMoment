import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            NavigationStack(path: $store.path) {
                CharacterWorldListView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .characterDetail:
                            CharacterDetailView()
                        case .chat:
                            ChatView()
                        case .momentAnalysis:
                            MomentAnalysisView()
                        case .momentPreview:
                            MomentPreviewView()
                        case .diagnostics:
                            PoCDiagnosticsView()
                        }
                    }
            }
            .tint(.white)

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
    }
}

enum AppRoute: Hashable {
    case characterDetail(UUID)
    case chat
    case momentAnalysis
    case momentPreview
    case diagnostics
}
