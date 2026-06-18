import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var selectedCategory = "전체"
    @State private var searchText = ""
    @State private var isShowingNotificationCenter = false

    private let categories = ["전체", "학교 로맨스", "소꿉친구", "판타지", "집착", "다정", "차가운 남주"]

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    searchField
                    if let recommended = store.recommendedCharacter {
                        recommendedBanner(recommended)
                    }
                    categoryChips
                    sections
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
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

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lovey Moment")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                Text("오늘 밤, 끊긴 장면을 다시 여는 캐릭터 월드")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Button {
                isShowingNotificationCenter = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.10)))

                    if store.notificationAuthorizationStatus != .authorized {
                        Circle()
                            .fill(PoCTheme.primary)
                            .frame(width: 9, height: 9)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("알림 센터 열기")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("캐릭터, 세계관 검색", text: $searchText)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private func recommendedBanner(_ character: CharacterProfile) -> some View {
        Button {
            store.openDetail(for: character)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CharacterHeroPortraitView(character: character, height: 230)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.45), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘의 추천 캐릭터")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PoCTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.4)))

                    Text(character.name)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(character.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        TagPill(text: character.stats.genreLabel, color: PoCTheme.secondary)
                        TagPill(text: "관심 \(character.stats.likeCountText)", color: PoCTheme.primary)
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.82) : .white.opacity(0.78))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(isSelected ? PoCTheme.primary : Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 26) {
            section(title: "지금 많이 대화 중", subtitle: "유저들이 가장 많이 이야기 나누는 캐릭터", characters: trending)
            section(title: "오늘 밤 Moment 가능", subtitle: "잠들기 전 알림으로 이어지는 월드", characters: momentReady)
            section(title: "새로 열린 세계관", subtitle: "최근 업데이트된 스토리", characters: newlyUpdated)
        }
    }

    private let cardColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    @ViewBuilder
    private func section(title: String, subtitle: String, characters: [CharacterProfile]) -> some View {
        if !characters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                LazyVGrid(columns: cardColumns, spacing: 16) {
                    ForEach(characters) { character in
                        HomeCharacterCardView(
                            character: character,
                            openDetail: { store.openDetail(for: character) },
                            startChat: { store.startChat(with: character) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Filtering / sections

    private var filtered: [CharacterProfile] {
        store.characters.filter { character in
            let matchesCategory = selectedCategory == "전체"
                || character.categoryTags.contains { $0.localizedCaseInsensitiveContains(selectedCategory) }
            let matchesSearch = searchText.isEmpty
                || character.name.localizedCaseInsensitiveContains(searchText)
                || character.subtitle.localizedCaseInsensitiveContains(searchText)
                || character.stats.genreLabel.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var trending: [CharacterProfile] {
        filtered.sorted { $0.stats.chatCount > $1.stats.chatCount }
    }

    private var momentReady: [CharacterProfile] {
        filtered.filter { $0.sleepMomentSettings.isBedtimeMomentEnabled }
    }

    private var newlyUpdated: [CharacterProfile] {
        filtered.sorted { $0.stats.followerCount > $1.stats.followerCount }
    }
}

/// 2열 그리드 카드. 이미지=정사각형(열 너비 가득), 이름/장르 오버레이, 설명·통계·CTA는 고정 높이로
/// 두어 모든 카드의 "대화하기" 버튼이 같은 위치에 정렬되도록 한다.
private struct HomeCharacterCardView: View {
    let character: CharacterProfile
    let openDetail: () -> Void
    let startChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openDetail) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        GeometryReader { geo in
                            portrait(width: geo.size.width)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(character.subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

            HStack(spacing: 8) {
                Label(character.stats.likeCountText, systemImage: "heart.fill")
                Label(character.stats.chatCountText, systemImage: "bubble.left.fill")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
            .frame(height: 16, alignment: .leading)

            Button(action: startChat) {
                Text("대화하기")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PoCTheme.primary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func portrait(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            CharacterPortraitView(character: character, size: width, style: .card)

            LinearGradient(
                colors: [.clear, .black.opacity(0.62)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(character.stats.genreLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(10)
        }
    }
}
