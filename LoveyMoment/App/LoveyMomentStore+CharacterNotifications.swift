import Foundation

/// 캐릭터 메시지 알림(자기 전/아침 + 답장 지연 follow-up) 예약 로직.
/// 모든 plan body는 예약 시점에 CharacterNotificationComposer로 생성하고,
/// 알림 탭 시 같은 body가 ChatView에 삽입된다(딥링크 파이프라인 재사용).
@MainActor
extension LoveyMomentStore {
    // MARK: - Enabled characters

    var notificationEnabledCharacters: [CharacterProfile] {
        characters.filter { notificationEnabledCharacterIDs.contains($0.id) }
    }

    func isNotificationEnabled(for character: CharacterProfile) -> Bool {
        notificationEnabledCharacterIDs.contains(character.id)
    }

    func setNotificationEnabled(_ isEnabled: Bool, for character: CharacterProfile) {
        if isEnabled {
            notificationEnabledCharacterIDs.insert(character.id)
        } else {
            notificationEnabledCharacterIDs.remove(character.id)
            scheduledNotificationPlans.removeAll { $0.characterId == character.id }
            Task { await environment.characterNotificationScheduler.cancelAll(characterId: character.id) }
        }
        refreshSleepBasedNotificationPlans()
    }

    func seedNotificationEnabledCharactersIfNeeded() {
        guard notificationEnabledCharacterIDs.isEmpty else { return }
        let enabled = characters.filter {
            $0.sleepMomentSettings.isBedtimeMomentEnabled || $0.sleepMomentSettings.isMorningMomentEnabled
        }
        if enabled.isEmpty, let recommended = recommendedCharacter {
            notificationEnabledCharacterIDs = [recommended.id]
        } else {
            notificationEnabledCharacterIDs = Set(enabled.map(\.id))
        }
    }

    // MARK: - Grouping helpers (UI)

    var bedtimeNotificationPlans: [CharacterNotificationPlan] {
        scheduledNotificationPlans.filter { $0.type == .bedtimeMoment }
    }

    var morningNotificationPlans: [CharacterNotificationPlan] {
        scheduledNotificationPlans.filter { $0.type == .morningMoment }
    }

    var followUpNotificationPlans: [CharacterNotificationPlan] {
        scheduledNotificationPlans.filter { $0.type == .delayedReply }
    }

    /// 다음 24시간 내 예정된 알림.
    var upcomingNotificationPlans: [CharacterNotificationPlan] {
        let limit = Date().addingTimeInterval(60 * 60 * 24)
        return scheduledNotificationPlans
            .filter { $0.scheduledDate <= limit }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // MARK: - Sleep-based scheduling

    /// 알림 ON 캐릭터들의 자기 전/아침 알림을 수면 리듬 기반으로 다시 예약한다.
    func refreshSleepBasedNotificationPlans() {
        Task { await rebuildSleepMomentPlans() }
    }

    private func rebuildSleepMomentPlans() async {
        // 64개 pending 한도를 고려해 알림 ON 캐릭터를 최대 8명까지만 예약한다.
        let targets = Array(notificationEnabledCharacters.prefix(8))

        for character in targets {
            await environment.characterNotificationScheduler.cancel(characterId: character.id, type: .bedtimeMoment)
            await environment.characterNotificationScheduler.cancel(characterId: character.id, type: .morningMoment)
        }
        scheduledNotificationPlans.removeAll {
            ($0.type == .bedtimeMoment || $0.type == .morningMoment)
        }

        var newPlans: [CharacterNotificationPlan] = []
        for character in targets {
            let (signal, source) = await sleepSignalAndSource(for: character)
            let bedtime = makeSleepPlan(character: character, type: .bedtimeMoment, signal: signal, source: source)
            let morning = makeSleepPlan(character: character, type: .morningMoment, signal: signal, source: source)
            for plan in [bedtime, morning] {
                print("[CharacterNotification] planCreated type=\(plan.type.rawValue) characterId=\(plan.characterId) at=\(plan.scheduledDate) source=\(plan.source.rawValue)")
                _ = await environment.characterNotificationScheduler.schedule(plan: plan)
                newPlans.append(plan)
            }
        }

        scheduledNotificationPlans.append(contentsOf: newPlans)
        scheduledNotificationPlans.sort { $0.scheduledDate < $1.scheduledDate }
    }

    private func sleepSignalAndSource(for character: CharacterProfile) async -> (SleepSignal?, CharacterNotificationSource) {
        let snapshot = ConversationSnapshot(
            character: character,
            worldSetting: world(for: character),
            relationshipStage: relationshipStage(for: character),
            recentMessages: messages(for: character),
            lastSceneSummary: lastSceneSummary(for: character),
            capturedAt: Date()
        )
        let result = await environment.sleepSignalProvider.currentSleepSignalResult(for: snapshot)
        let source: CharacterNotificationSource = result.diagnostics.source == .healthKitRealData ? .healthKit : .fallbackRhythm
        return (result.signal, source)
    }

    private func makeSleepPlan(
        character: CharacterProfile,
        type: CharacterNotificationType,
        signal: SleepSignal?,
        source: CharacterNotificationSource
    ) -> CharacterNotificationPlan {
        let timeString: String
        let offset: Int
        switch type {
        case .morningMoment:
            timeString = signal?.estimatedWakeTime ?? "07:20"
            offset = 20 // 기상 +10~30분 범위의 중앙값
        default:
            timeString = signal?.estimatedBedtime ?? "23:40"
            offset = -30 // 취침 −20~40분 범위의 중앙값
        }
        let date = CharacterNotificationSchedule.nextDate(timeString: timeString, offsetMinutes: offset)
        let context = makeTriggerContext(character: character, triggerType: type, signal: signal)
        let composed = notificationComposer.compose(context: context)
        return CharacterNotificationPlan(
            characterId: character.id,
            characterName: character.name,
            type: type,
            scheduledDate: date,
            title: composed.title,
            body: composed.body,
            source: source
        )
    }

    private func makeTriggerContext(
        character: CharacterProfile,
        triggerType: CharacterNotificationType,
        signal: SleepSignal?,
        appLifecycleEvent: String? = nil
    ) -> CharacterNotificationTriggerContext {
        CharacterNotificationTriggerContext(
            character: character,
            recentMessages: messages(for: character),
            sleepSignal: signal,
            momentSettings: momentSettings,
            relationshipStage: relationshipStage(for: character),
            lastSceneSummary: lastSceneSummary(for: character),
            appLifecycleEvent: appLifecycleEvent,
            triggerType: triggerType
        )
    }

    // MARK: - Delayed-reply follow-up

    /// 앱이 백그라운드로 갈 때, 마지막 메시지가 캐릭터의 답장이고 사용자가 응답하지 않았다면
    /// 답장 지연(follow-up) 알림을 예약한다.
    func handleAppDidEnterBackground() {
        guard let character = selectedCharacter else { return }
        guard isNotificationEnabled(for: character) else { return }
        let msgs = messages(for: character)
        guard let last = msgs.last, last.sender == .character else { return }
        scheduleFollowUpNotification(for: character, after: 30 * 60)
    }

    /// 답장 지연 알림 예약. seconds 기본값은 30분(production 15분~2시간 범위 내).
    func scheduleFollowUpNotification(for character: CharacterProfile, after seconds: TimeInterval) {
        Task {
            // 중복 스택 방지: 기존 follow-up을 먼저 취소한다.
            await environment.characterNotificationScheduler.cancel(characterId: character.id, type: .delayedReply)
            scheduledNotificationPlans.removeAll { $0.characterId == character.id && $0.type == .delayedReply }

            let (signal, _) = await sleepSignalAndSource(for: character)
            let context = makeTriggerContext(
                character: character,
                triggerType: .delayedReply,
                signal: signal,
                appLifecycleEvent: "didEnterBackground"
            )
            let composed = notificationComposer.compose(context: context)
            let plan = CharacterNotificationPlan(
                characterId: character.id,
                characterName: character.name,
                type: .delayedReply,
                scheduledDate: Date().addingTimeInterval(seconds),
                title: composed.title,
                body: composed.body,
                source: .conversationTrigger
            )
            print("[CharacterNotification] planCreated type=delayedReply characterId=\(character.id) fireIn=\(Int(seconds))s")
            _ = await environment.characterNotificationScheduler.schedule(plan: plan)
            scheduledNotificationPlans.append(plan)
            scheduledNotificationPlans.sort { $0.scheduledDate < $1.scheduledDate }
        }
    }

    /// 사용자가 다시 답장하면 예약된 follow-up을 취소한다.
    func cancelFollowUpNotification(for character: CharacterProfile) {
        scheduledNotificationPlans.removeAll { $0.characterId == character.id && $0.type == .delayedReply }
        Task { await environment.characterNotificationScheduler.cancel(characterId: character.id, type: .delayedReply) }
    }

    // MARK: - Test follow-up (30s)

    /// 30초 뒤 답장 지연 알림을 보내는 테스트. (알림 센터/MomentHub 버튼)
    func scheduleTestCharacterNotification() {
        guard let character = selectedCharacter ?? recommendedCharacter ?? characters.first else { return }
        Task {
            let (signal, _) = await sleepSignalAndSource(for: character)
            let context = makeTriggerContext(
                character: character,
                triggerType: .delayedReply,
                signal: signal,
                appLifecycleEvent: "manualTest"
            )
            let composed = notificationComposer.compose(context: context)
            let plan = CharacterNotificationPlan(
                characterId: character.id,
                characterName: character.name,
                type: .delayedReply,
                scheduledDate: Date().addingTimeInterval(30),
                title: composed.title,
                body: composed.body,
                source: .manualTest
            )
            let identifier = await environment.characterNotificationScheduler.scheduleTest(plan: plan, after: 30)
            notificationAuthorizationStatus = await environment.characterNotificationScheduler.authorizationStatus()
            if identifier != nil {
                testNotificationStatusText = "30초 뒤 \(character.name)의 메시지가 도착해요."
                toastMessage = "30초 뒤 캐릭터 메시지를 보냈어요. 잠금화면을 확인해보세요."
            } else {
                testNotificationStatusText = "알림 권한이 꺼져 있어 메시지를 보내지 못했어요."
                toastMessage = "설정에서 알림을 허용하면 캐릭터 메시지를 받을 수 있어요."
            }
        }
    }
}
