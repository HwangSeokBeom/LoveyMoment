import Foundation

/// 홈 추천 회전, 당겨서 새로고침, 검색, 알림 센터 활동 피드 등
/// 실제 서비스형 사용성 동작을 모은 확장.
@MainActor
extension LoveyMomentStore {

    // MARK: - Home recommendation

    /// 새로고침마다 바뀌는 오늘의 추천 캐릭터. 시드로 회전한다.
    var homeRecommendedCharacter: CharacterProfile? {
        guard !characters.isEmpty else { return nil }
        let ranked = characters.sorted { $0.stats.likeCount > $1.stats.likeCount }
        let index = ((homeRecommendationSeed % ranked.count) + ranked.count) % ranked.count
        return ranked[index]
    }

    /// 검색 추천어. 캐릭터/세계관 결을 반영한다.
    var recommendedSearchTerms: [String] {
        ["차가운 남주", "소꿉친구", "집착", "다정한 선배", "뱀파이어", "학교 로맨스", "판타지"]
    }

    /// 인기 태그. 보유 캐릭터의 카테고리 태그에서 모은다.
    var popularSearchTags: [String] {
        var seen: [String] = []
        for character in characters {
            for tag in character.categoryTags where !seen.contains(tag) {
                seen.append(tag)
            }
        }
        return Array(seen.prefix(8))
    }

    /// 검색어로 캐릭터를 필터링한다. name/subtitle/세계관/태그/카테고리를 모두 살핀다.
    func searchedCharacters(for query: String) -> [CharacterProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return characters.filter { character in
            let world = world(for: character)
            let haystacks: [String] = [
                character.name,
                character.subtitle,
                character.shortDescription,
                character.stats.genreLabel,
                world.title,
                world.summary
            ] + character.tags + character.categoryTags + world.categoryTags
            return haystacks.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    // MARK: - Pull to refresh

    func refreshHome() async {
        await simulateRefresh(0.5)
        homeRecommendationSeed += 1
    }

    func refreshChatList() async {
        await simulateRefresh(0.5)
    }

    func refreshMoment() async {
        await simulateRefresh(0.6)
        refreshNotificationAuthorizationStatus()
        refreshSleepBasedNotificationPlans()
    }

    func refreshSignal() async {
        await simulateRefresh(0.5)
    }

    func refreshDatingRecommendations() async {
        await simulateRefresh(0.7)
        if let profile = relationshipPreferenceProfile {
            datingMatchCandidates = environment.datingSignalAnalyzer.recommendedCandidates(for: profile)
        }
    }

    private func simulateRefresh(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        lastRefreshedAt = Date()
    }

    var lastRefreshedText: String? {
        guard let date = lastRefreshedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return "마지막 업데이트 \(formatter.string(from: date))"
    }

    // MARK: - Activity notification center

    /// 당근 스타일 활동 피드. 캐릭터 메시지/Moment/Signal/설정 항목을 한곳에 모은다.
    var activityNotificationItems: [AppNotificationItem] {
        var items: [AppNotificationItem] = []
        let now = Date()

        // 캐릭터 메시지 (예정된 캐릭터 알림)
        for plan in upcomingNotificationPlans {
            items.append(
                AppNotificationItem(
                    id: "char.\(plan.id.uuidString)",
                    category: .character,
                    title: "\(plan.characterName) · \(plan.type.userFacingLabel)",
                    body: plan.body,
                    date: plan.scheduledDate,
                    isRead: readNotificationIDs.contains("char.\(plan.id.uuidString)"),
                    iconName: plan.type.iconName,
                    characterId: plan.characterId,
                    destination: .chat(plan.characterId)
                )
            )
        }

        // Moment 예약
        if let recommended = recommendedCharacter {
            let id = "moment.daily"
            items.append(
                AppNotificationItem(
                    id: id,
                    category: .moment,
                    title: "오늘 밤 Moment가 준비돼요",
                    body: "\(recommended.name)와의 끊긴 장면을 잠들기 전에 다시 열어드릴게요.",
                    date: now.addingTimeInterval(-1800),
                    isRead: readNotificationIDs.contains(id),
                    iconName: "moon.stars.fill",
                    characterId: recommended.id,
                    destination: .momentTab
                )
            )
        }

        // Signal 추천
        if let profile = relationshipPreferenceProfile {
            let id = "signal.\(profile.id.uuidString)"
            items.append(
                AppNotificationItem(
                    id: id,
                    category: .signal,
                    title: "취향 분석으로 추천 예시가 도착했어요",
                    body: profile.headline,
                    date: profile.createdAt,
                    isRead: readNotificationIDs.contains(id),
                    iconName: "heart.text.square.fill",
                    characterId: nil,
                    destination: .signalTab
                )
            )
        } else {
            let id = "signal.intro"
            items.append(
                AppNotificationItem(
                    id: id,
                    category: .signal,
                    title: "관계 취향을 분석해볼까요?",
                    body: "최애 캐릭터 대화로 어떤 관계를 편안해하는지 살펴볼 수 있어요.",
                    date: now.addingTimeInterval(-7200),
                    isRead: readNotificationIDs.contains(id),
                    iconName: "sparkles",
                    characterId: nil,
                    destination: .signalTab
                )
            )
        }

        // 건강 앱 상태
        let healthID = "system.health"
        items.append(
            AppNotificationItem(
                id: healthID,
                category: .system,
                title: "수면 리듬 연결 상태",
                body: healthConnectMessage ?? "건강 앱을 연결하면 수면 리듬에 맞춰 메시지를 받을 수 있어요.",
                date: now.addingTimeInterval(-10800),
                isRead: readNotificationIDs.contains(healthID),
                iconName: "bed.double.fill",
                characterId: nil,
                destination: .healthSettings
            )
        )

        // 알림 설정 상태
        let settingsID = "system.notification"
        let authorized = notificationAuthorizationStatus == .authorized
        items.append(
            AppNotificationItem(
                id: settingsID,
                category: .system,
                title: authorized ? "알림이 켜져 있어요" : "알림을 켜면 메시지를 받을 수 있어요",
                body: authorized
                    ? "캐릭터가 잠들기 전·아침에 직접 말을 걸어요."
                    : "알림을 허용하면 캐릭터 메시지와 Moment를 받을 수 있어요.",
                date: now.addingTimeInterval(-14400),
                isRead: readNotificationIDs.contains(settingsID),
                iconName: "bell.badge.fill",
                characterId: nil,
                destination: .notificationSettings
            )
        )

        return items.sorted { $0.date > $1.date }
    }

    var unreadNotificationCount: Int {
        activityNotificationItems.filter { !$0.isRead }.count
    }

    func markNotificationRead(_ item: AppNotificationItem) {
        readNotificationIDs.insert(item.id)
    }

    func markAllNotificationsRead() {
        readNotificationIDs.formUnion(activityNotificationItems.map(\.id))
    }

    /// 알림 항목 탭 시 목적지로 이동한다.
    func openNotification(_ item: AppNotificationItem) {
        markNotificationRead(item)
        switch item.destination {
        case .chat(let characterId):
            if let character = characters.first(where: { $0.id == characterId }) {
                selectedTab = .chat
                selectedCharacter = character
                momentSettings = character.sleepMomentSettings
                chatPath = [.chat]
            }
        case .momentTab:
            selectedTab = .moment
        case .signalTab:
            selectedTab = .signal
        case .notificationSettings:
            if notificationAuthorizationStatus == .denied {
                openSystemNotificationSettings()
            } else if notificationAuthorizationStatus == .notDetermined {
                requestNotificationAuthorization()
            }
        case .healthSettings:
            selectedTab = .my
        case .none:
            break
        }
    }
}
