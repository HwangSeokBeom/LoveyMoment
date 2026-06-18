import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case chat
    case moment
    case signal
    case my

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "홈"
        case .chat: return "채팅"
        case .moment: return "Moment"
        case .signal: return "시그널"
        case .my: return "MY"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .moment: return "moon.stars.fill"
        case .signal: return "heart.text.square.fill"
        case .my: return "person.fill"
        }
    }
}

/// 실제 서비스형 하단 탭바. 각 탭은 자체 NavigationStack을 가지며,
/// 기존 화면(CharacterDetail/Chat/MomentAnalysis/MomentPreview/Diagnostics)을 재사용한다.
struct MainTabView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.home, path: $store.homePath) { HomeView() }
            tab(.chat, path: $store.chatPath) { ChatListView() }
            tab(.moment, path: $store.momentPath) { MomentHubView() }
            tab(.signal, path: $store.signalPath) { SignalHomeView() }
            tab(.my, path: $store.myPath) { MyView() }
        }
        .tint(PoCTheme.primary)
    }

    private func tab<Root: View>(
        _ tab: MainTab,
        path: Binding<[AppRoute]>,
        @ViewBuilder root: () -> Root
    ) -> some View {
        NavigationStack(path: path) {
            root()
                .appRouteDestinations()
        }
        .tint(.white)
        .tabItem {
            Label(tab.title, systemImage: tab.systemImage)
        }
        .tag(tab)
    }
}

extension View {
    /// 모든 탭의 NavigationStack이 공유하는 라우트 destination 매핑.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
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
            case .datingSignalIntro:
                DatingSignalConsentView()
            case .datingSignalSelection:
                FavoriteConversationSelectionView()
            case .datingSignalAnalysis:
                RelationshipPreferenceAnalysisView()
            case .datingSignalProfile:
                DatingPreferenceProfileView()
            case .datingSignalRecommendations:
                DatingMatchRecommendationView()
            case .datingSignalCandidateDetail:
                DatingMatchDetailView()
            }
        }
    }
}
