import Foundation
import UserNotifications
import UIKit

@MainActor
final class LoveyMomentStore: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var homePath: [AppRoute] = []
    @Published var chatPath: [AppRoute] = []
    @Published var momentPath: [AppRoute] = []
    @Published var libraryPath: [AppRoute] = []
    @Published var myPath: [AppRoute] = []
    @Published var isHealthConnecting = false
    @Published var healthConnectMessage: String?
    @Published var characters: [CharacterProfile] = []
    @Published var selectedCharacter: CharacterProfile?
    @Published var messagesByConversation: [UUID: [ChatMessage]] = [:]
    @Published var currentSnapshot: ConversationSnapshot?
    @Published var currentSleepSignal: SleepSignal?
    @Published var currentSleepDiagnostics: SleepSignalDiagnostics = .empty
    @Published var currentAnalysis: MomentAnalysis?
    @Published var momentSettings = MomentSettings()
    @Published var pendingInsertedMoment: MomentMessage?
    @Published var pendingNotificationRoute: AppNotificationRoute?
    @Published var scheduledMoments: [MomentMessage] = []
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var testNotificationStatusText: String?
    @Published var currentConversationGenerationMode: ConversationGenerationMode = .localDeterministicFallback
    @Published var nativeLLMAvailability: ConversationGenerationAvailability = .unavailable(reason: "notChecked")
    @Published var nativeLLMDiagnostics: NativeLLMDiagnostics = .empty
    @Published var foundationModelsCompileAvailable = false
    @Published var isGeneratingReply = false
    @Published var generationStatusText: String?
    @Published var lastScheduledNotificationID: String?
    @Published var lastNotificationRoute: AppNotificationRoute?
    @Published var lastInsertedMomentID: UUID?
    @Published var isAnalyzing = false
    @Published var isScheduling = false
    @Published var toastMessage: String?
    @Published var scheduledNotificationPlans: [CharacterNotificationPlan] = []
    @Published var notificationEnabledCharacterIDs: Set<UUID> = []
    @Published var signalPath: [AppRoute] = []
    @Published var datingSignalConsent = DatingSignalConsent.empty
    @Published var signalConversationSelections: [FavoriteConversationSelection] = []
    @Published var relationshipPreferenceProfile: RelationshipPreferenceProfile?
    @Published var datingMatchCandidates: [DatingMatchCandidate] = []
    @Published var datingSignalAnalysisState: DatingSignalAnalysisState = .idle
    @Published var datingSignalErrorMessage: String?
    @Published var selectedDatingCandidate: DatingMatchCandidate?
    @Published var homeRecommendationSeed = 0
    @Published var lastRefreshedAt: Date?
    @Published var readNotificationIDs: Set<String> = []
    @Published var homeScrollToTopToken = 0
    @Published var chatScrollToTopToken = 0
    @Published var momentScrollToTopToken = 0
    @Published var signalScrollToTopToken = 0
    @Published var datingScrollToTopToken = 0

    let notificationComposer = CharacterNotificationComposer()
    private var hasRequestedNotificationPermissionInSession = false
    private var insertedMomentIDs: Set<UUID> = []
    let environment: AppEnvironment
    private let worldsByID: [UUID: WorldSetting]
    private let relationshipStagesByID: [UUID: RelationshipStage]
    private let lastSceneSummariesByCharacterID: [UUID: String]
    private let snapshotsByCharacterID: [UUID: [ConversationSnapshot]]

    init(environment: AppEnvironment) {
        self.environment = environment

        let seed = MockCharacterRepository.makeSeedData()
        self.characters = seed.characters
        self.messagesByConversation = seed.messagesByConversation
        self.worldsByID = Dictionary(uniqueKeysWithValues: seed.worlds.map { ($0.id, $0) })
        self.relationshipStagesByID = Dictionary(uniqueKeysWithValues: seed.relationshipStages.map { ($0.id, $0) })
        self.lastSceneSummariesByCharacterID = seed.lastSceneSummariesByCharacterID
        self.snapshotsByCharacterID = seed.snapshotsByCharacterID
        refreshConversationGeneratorStatus()
    }

    /// 현재 선택된 탭의 NavigationStack에 라우트를 push 한다.
    func push(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .chat: chatPath.append(route)
        case .moment: momentPath.append(route)
        case .signal: signalPath.append(route)
        case .my: myPath.append(route)
        }
    }

    func world(for character: CharacterProfile) -> WorldSetting {
        worldsByID[character.worldSettingID] ?? MockCharacterRepository.fallbackWorld
    }

    func relationshipStage(for character: CharacterProfile) -> RelationshipStage {
        relationshipStagesByID[character.initialRelationshipStageID] ?? MockCharacterRepository.fallbackRelationshipStage
    }

    func lastSceneSummary(for character: CharacterProfile) -> String {
        lastSceneSummariesByCharacterID[character.id] ?? ""
    }

    func seedSnapshots(for character: CharacterProfile) -> [ConversationSnapshot] {
        snapshotsByCharacterID[character.id] ?? []
    }

    func messages(for character: CharacterProfile) -> [ChatMessage] {
        messagesByConversation[character.id] ?? []
    }

    func openDetail(for character: CharacterProfile) {
        selectedCharacter = character
        momentSettings = character.sleepMomentSettings
        push(.characterDetail(character.id))
    }

    func startChat(with character: CharacterProfile) {
        selectedCharacter = character
        momentSettings = character.sleepMomentSettings
        push(.chat)
    }

    func openDiagnostics() {
        refreshConversationGeneratorStatus()
        push(.diagnostics)
    }

    func bootstrapAppSession() {
        refreshConversationGeneratorStatus()
        requestNotificationAuthorizationIfNeeded(source: "appBootstrap")
        seedNotificationEnabledCharactersIfNeeded()
        refreshSleepBasedNotificationPlans()
    }

    func refreshConversationGeneratorStatus() {
        foundationModelsCompileAvailable = environment.conversationGenerator.compileAvailability
        nativeLLMAvailability = environment.conversationGenerator.availabilityStatus()
        currentConversationGenerationMode = nativeLLMAvailability.isAvailable ? .nativeFoundationModel : .highQualityAssistant
        print("[ConversationGenerator] compileFoundationModels=\(foundationModelsCompileAvailable) availability=\(nativeLLMAvailability.displayText) selectedMode=\(currentConversationGenerationMode.rawValue)")
        Task {
            await refreshNativeLLMDiagnostics()
        }
    }

    func refreshNativeLLMDiagnostics() async {
        nativeLLMDiagnostics = await environment.conversationGenerator.nativeLLMDiagnosticsSnapshot()
    }

    func requestNotificationAuthorization() {
        requestNotificationAuthorizationIfNeeded(source: "manual", force: true)
    }

    func requestNotificationAuthorizationIfNeeded(source: String, force: Bool = false) {
        Task {
            let status = await environment.notificationScheduler.authorizationStatus()
            notificationAuthorizationStatus = status

            switch status {
            case .notDetermined:
                guard force || !hasRequestedNotificationPermissionInSession else {
                    print("[NotificationPermission] source=\(source) status=notDetermined skipRequest=sessionGuard")
                    return
                }
                hasRequestedNotificationPermissionInSession = true
                let granted = await environment.notificationScheduler.requestAuthorization()
                notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
                toastMessage = granted ? "알림 권한이 준비됐어요." : "알림 권한이 꺼져 있어요. 미리보기는 계속 사용할 수 있어요."
            case .authorized, .provisional, .ephemeral:
                print("[NotificationPermission] source=\(source) status=\(status.logName) skipRequest")
                if force {
                    toastMessage = "알림이 이미 켜져 있어요. Moment 알림을 받을 수 있어요."
                }
            case .denied:
                print("[NotificationPermission] source=\(source) status=denied showInAppGuide")
                toastMessage = "설정에서 알림을 허용하면 Moment 알림을 받을 수 있어요."
            @unknown default:
                print("[NotificationPermission] source=\(source) status=unknown showInAppGuide")
            }
        }
    }

    /// 분석 흐름 없이도 알림 동작을 확인할 수 있는 10초 테스트 알림.
    /// 홈/알림 센터에서 바로 호출된다.
    func scheduleStandaloneTestNotification() {
        guard let character = recommendedCharacter ?? characters.first else { return }
        let summary = lastSceneSummary(for: character)
        let moment = MomentMessage(
            type: .bedtime,
            characterName: character.name,
            title: "\(character.name)의 Lovey Moment",
            body: summary.isEmpty
                ? "잠들기 전, \(character.name)가 마지막 장면을 다시 꺼냈어요."
                : "잠들기 전, \(character.name)가 \(summary.prefix(40))… 라며 말을 걸어요.",
            scheduledAt: "방금",
            isEnabled: true,
            analysisID: UUID()
        )
        Task {
            let identifier = await environment.notificationScheduler.scheduleTest(moment: moment, characterID: character.id)
            notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
            if let identifier {
                lastScheduledNotificationID = identifier
                testNotificationStatusText = "10초 뒤 \(character.name)의 테스트 알림이 도착해요."
                toastMessage = "10초 뒤 테스트 알림을 보냈어요. 잠금화면을 확인해보세요."
            } else {
                testNotificationStatusText = "알림 권한이 꺼져 있어 테스트 알림을 보내지 못했어요."
                toastMessage = "설정에서 알림을 허용하면 Moment 알림을 받을 수 있어요."
            }
        }
    }

    /// iOS 설정 앱의 본 앱 알림 화면을 연다. (권한 거부 시 복구 경로)
    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            if UIApplication.shared.canOpenURL(url) {
                await UIApplication.shared.open(url)
                print("[NotificationPermission] openSystemSettings")
            }
        }
    }

    /// 추천(가장 관심 많은) 캐릭터.
    var recommendedCharacter: CharacterProfile? {
        characters.max { $0.stats.likeCount < $1.stats.likeCount }
    }

    func refreshNotificationAuthorizationStatus() {
        Task {
            notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
        }
    }

    /// "건강 앱 연결" 동작. HealthKit 권한을 요청하고 수면 쿼리를 다시 시도한 뒤
    /// 사용자에게 왜 실데이터/대체 신호가 쓰이는지 알려준다.
    func connectHealthKit() {
        guard let character = recommendedCharacter ?? characters.first else { return }
        isHealthConnecting = true
        healthConnectMessage = nil
        print("[HealthKit] connect=requestStart source=myTab")

        Task {
            let snapshot = ConversationSnapshot(
                character: character,
                worldSetting: world(for: character),
                relationshipStage: relationshipStage(for: character),
                recentMessages: messages(for: character),
                lastSceneSummary: lastSceneSummary(for: character),
                capturedAt: Date()
            )
            let result = await environment.sleepSignalProvider.currentSleepSignalResult(for: snapshot)
            currentSleepSignal = result.signal
            currentSleepDiagnostics = result.diagnostics
            healthConnectMessage = healthStatusMessage(for: result.diagnostics)
            isHealthConnecting = false
            print("[HealthKit] connect=done source=\(result.diagnostics.source.displayName) fallback=\(result.diagnostics.fallbackReason ?? "none")")
        }
    }

    /// HealthKit 진단을 사용자 친화 문장으로 변환한다.
    func healthStatusMessage(for diagnostics: SleepSignalDiagnostics) -> String {
        if diagnostics.source == .healthKitRealData {
            return "건강 앱 수면 기록 \(diagnostics.sampleCount)개를 불러왔어요. 실제 수면 리듬으로 Moment 시간을 맞춰드려요."
        }
        switch diagnostics.fallbackReason {
        case "simulatorOrUnavailable":
            return "지금은 시뮬레이터라 건강 데이터를 읽을 수 없어요. 실제 기기에서 건강 앱을 연결하면 수면 리듬이 반영돼요."
        case "healthDataUnavailable":
            return "이 기기에서는 건강 데이터를 사용할 수 없어, 기본 수면 리듬으로 Moment를 준비했어요."
        case "authorizationDenied":
            return "건강 앱 권한이 거부돼 있어요. 설정 > 개인정보 보호 > 건강에서 수면 읽기를 허용하면 실제 리듬이 반영돼요."
        case "noSleepSamples":
            return "최근 수면 기록이 없어 기본 리듬을 사용 중이에요. 며칠 수면이 기록되면 자동으로 실데이터가 반영돼요."
        case "missingSleepType":
            return "이 기기에서 수면 분석 항목을 찾을 수 없어 기본 리듬을 사용해요."
        default:
            return "지금은 기본 수면 리듬으로 Moment를 준비했어요. 건강 앱이 연결되면 실제 리듬으로 바뀌어요."
        }
    }

    /// Moment 탭에서 캐릭터를 골라 분석 흐름을 시작한다.
    func startMomentAnalysis(for character: CharacterProfile) {
        selectedCharacter = character
        momentSettings = character.sleepMomentSettings
        generateMomentAnalysis()
    }

    func generateMomentAnalysis() {
        guard let character = selectedCharacter else { return }
        isAnalyzing = true

        Task {
            let snapshot = ConversationSnapshot(
                character: character,
                worldSetting: world(for: character),
                relationshipStage: relationshipStage(for: character),
                recentMessages: messages(for: character),
                lastSceneSummary: lastSceneSummary(for: character),
                capturedAt: Date()
            )

            let sleepResult = await environment.sleepSignalProvider.currentSleepSignalResult(for: snapshot)
            let analysis = environment.momentAnalyzer.analyze(snapshot: snapshot, sleepSignal: sleepResult.signal)
            let generatedAnalysis = await generateMomentMessages(for: analysis, snapshot: snapshot, sleepSignal: sleepResult.signal)

            currentSnapshot = snapshot
            currentSleepSignal = sleepResult.signal
            currentSleepDiagnostics = sleepResult.diagnostics
            currentAnalysis = generatedAnalysis
            scheduledMoments = []
            isAnalyzing = false
            push(.momentAnalysis)
        }
    }

    func updateBedtimeMomentEnabled(_ isEnabled: Bool) {
        momentSettings.isBedtimeMomentEnabled = isEnabled
        reconcileMomentSchedule()
    }

    func updateMorningMomentEnabled(_ isEnabled: Bool) {
        momentSettings.isMorningMomentEnabled = isEnabled
        reconcileMomentSchedule()
    }

    func goToMomentPreview() {
        guard let analysis = currentAnalysis, let character = selectedCharacter else { return }
        isScheduling = true

        Task {
            let moments = enabledMoments(from: analysis)
            scheduledMoments = await environment.notificationScheduler.schedule(
                moments: moments,
                settings: momentSettings,
                characterID: character.id
            )
            notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
            isScheduling = false
            push(.momentPreview)
        }
    }

    func scheduleTestNotification() {
        guard let moment = preferredMomentForContinuation, let character = selectedCharacter else { return }
        Task {
            let identifier = await environment.notificationScheduler.scheduleTest(moment: moment, characterID: character.id)
            if let identifier {
                lastScheduledNotificationID = identifier
                testNotificationStatusText = "10초 뒤 테스트 알림 예약됨 · \(identifier)"
                toastMessage = "10초 뒤 테스트 알림을 예약했어요."
            } else {
                testNotificationStatusText = "알림 권한이 꺼져 있어 테스트 알림을 예약하지 못했어요."
                toastMessage = "설정에서 알림을 허용하면 Moment 알림을 받을 수 있어요."
            }
            notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
        }
    }

    func continueFromMomentPreview() {
        guard let moment = preferredMomentForContinuation, let character = selectedCharacter else { return }
        environment.notificationScheduler.handlePreviewTap(moment: moment)
        let route = AppNotificationRoute(
            characterId: character.id,
            momentId: moment.id,
            momentType: moment.type,
            deepLinkTarget: "chat",
            title: moment.title,
            body: moment.body
        )
        handleNotificationRoute(route)
        consumePendingNotificationRoute()
    }

    func insertPendingMomentIfNeeded() {
        guard let moment = pendingInsertedMoment, let character = selectedCharacter else { return }
        insertMomentMessageIfNeeded(character: character, moment: moment)
        pendingInsertedMoment = nil
    }

    func insertMomentMessageIfNeeded(character: CharacterProfile, moment: MomentMessage) {
        let label = ChatMessage(
            sender: .system,
            text: "알림에서 이어진 대화",
            createdAt: Date(),
            isMomentInserted: true,
            sourceMomentID: moment.id,
            generationMode: moment.generationMode
        )
        let message = ChatMessage(
            sender: .character,
            text: moment.body,
            createdAt: Date(),
            isMomentInserted: true,
            sourceMomentID: moment.id,
            generationMode: moment.generationMode
        )

        var messages = messagesByConversation[character.id] ?? []
        guard !insertedMomentIDs.contains(moment.id),
              !messages.contains(where: { $0.sourceMomentID == moment.id })
        else {
            print("[MomentInsert] skip duplicate momentId=\(moment.id)")
            return
        }

        messages.append(label)
        messages.append(message)
        messagesByConversation[character.id] = messages
        insertedMomentIDs.insert(moment.id)
        lastInsertedMomentID = moment.id
        print("[MomentInsert] inserted momentId=\(moment.id)")
    }

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let character = selectedCharacter else { return }

        cancelFollowUpNotification(for: character)

        var messages = messagesByConversation[character.id] ?? []
        messages.append(ChatMessage(sender: .user, text: trimmed, createdAt: Date()))
        messagesByConversation[character.id] = messages
        isGeneratingReply = true
        refreshConversationGeneratorStatus()
        generationStatusText = "답장을 쓰는 중…"

        Task {
            let context = ConversationGenerationContext(
                character: character,
                world: world(for: character),
                relationshipStage: relationshipStage(for: character),
                messages: messages,
                sleepSignal: currentSleepSignal,
                lastSceneSummary: lastSceneSummary(for: character),
                now: Date()
            )
            let reply: ChatMessage
            do {
                reply = try await environment.conversationGenerator.generateReply(context: context)
            } catch {
                print("[ConversationGenerator] unexpectedFailure reason=\(error.localizedDescription)")
                reply = ChatMessage(
                    sender: .character,
                    text: "지금은 짧게만 말할게. 그래도 네 말은 놓치지 않았어.",
                    createdAt: Date(),
                    generationMode: .localDeterministicFallback
                )
            }

            var updatedMessages = messagesByConversation[character.id] ?? messages
            updatedMessages.append(reply)
            messagesByConversation[character.id] = updatedMessages
            currentConversationGenerationMode = reply.generationMode ?? .localDeterministicFallback
            await refreshNativeLLMDiagnostics()
            generationStatusText = nil
            isGeneratingReply = false
        }
    }

    func generateScenario(_ scenario: ConversationScenario) {
        guard let character = selectedCharacter else { return }
        var messages = messagesByConversation[character.id] ?? []
        refreshConversationGeneratorStatus()
        isGeneratingReply = true
        generationStatusText = "답장을 쓰는 중…"

        Task {
            let context = ConversationGenerationContext(
                character: character,
                world: world(for: character),
                relationshipStage: relationshipStage(for: character),
                messages: messages,
                sleepSignal: currentSleepSignal,
                lastSceneSummary: lastSceneSummary(for: character),
                now: Date()
            )
            let message = (try? await environment.conversationGenerator.generateScenarioMessage(scenario: scenario, context: context)) ?? ChatMessage(
                sender: .character,
                text: "이 장면은 잠깐 숨겨둘게. 대신 네가 먼저 이어줘.",
                createdAt: Date(),
                generationMode: .localDeterministicFallback
            )
            messages.append(message)
            messagesByConversation[character.id] = messages
            currentConversationGenerationMode = message.generationMode ?? .localDeterministicFallback
            await refreshNativeLLMDiagnostics()
            generationStatusText = nil
            isGeneratingReply = false
        }
    }

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        guard let route = AppNotificationRoute(userInfo: userInfo) else { return }
        handleNotificationRoute(route)
    }

    func handleNotificationRoute(_ route: AppNotificationRoute) {
        guard characters.contains(where: { $0.id == route.characterId }) else {
            print("[DeepLink] unknownCharacter characterId=\(route.characterId)")
            return
        }
        pendingNotificationRoute = route
        lastNotificationRoute = route
        print("[DeepLink] pendingRoute set characterId=\(route.characterId) momentId=\(route.momentId) target=\(route.deepLinkTarget)")
    }

    func consumePendingNotificationRoute() {
        guard let route = pendingNotificationRoute else { return }
        pendingNotificationRoute = nil

        guard let character = characters.first(where: { $0.id == route.characterId }) else {
            print("[DeepLink] consume failed unknownCharacter characterId=\(route.characterId)")
            return
        }

        selectedCharacter = character
        momentSettings = character.sleepMomentSettings

        let moment = findMoment(id: route.momentId) ?? MomentMessage(
            id: route.momentId,
            type: route.momentType,
            characterName: character.name,
            title: route.title,
            body: route.body,
            scheduledAt: "방금",
            isEnabled: true,
            analysisID: currentAnalysis?.id ?? UUID()
        )

        pendingInsertedMoment = moment
        selectedTab = .chat
        chatPath = [.chat]
        insertPendingMomentIfNeeded()
        print("[DeepLink] navigate chat tab characterId=\(character.id)")
    }

    var preferredMomentForContinuation: MomentMessage? {
        guard let analysis = currentAnalysis else { return nil }
        if momentSettings.isMorningMomentEnabled {
            return analysis.morningMoment.withEnabled(true)
        }
        if momentSettings.isBedtimeMomentEnabled {
            return analysis.bedtimeMoment.withEnabled(true)
        }
        return nil
    }

    var canContinueFromPreview: Bool {
        preferredMomentForContinuation != nil
    }

    func momentCards() -> [MomentMessage] {
        guard let analysis = currentAnalysis else { return [] }
        return [
            analysis.bedtimeMoment.withEnabled(momentSettings.isBedtimeMomentEnabled),
            analysis.morningMoment.withEnabled(momentSettings.isMorningMomentEnabled)
        ]
    }

    private func generateMomentMessages(
        for analysis: MomentAnalysis,
        snapshot: ConversationSnapshot,
        sleepSignal: SleepSignal
    ) async -> MomentAnalysis {
        let summary = [
            analysis.characterInsight,
            analysis.relationshipInsight,
            analysis.emotionInsight,
            analysis.toneDecision.reason
        ].joined(separator: " ")

        let bedtime = await generateMomentMessage(
            type: .bedtime,
            baseMoment: analysis.bedtimeMoment,
            snapshot: snapshot,
            sleepSignal: sleepSignal,
            summary: summary
        )
        let morning = await generateMomentMessage(
            type: .morning,
            baseMoment: analysis.morningMoment,
            snapshot: snapshot,
            sleepSignal: sleepSignal,
            summary: summary
        )
        return analysis.replacingMoments(bedtime: bedtime, morning: morning)
    }

    private func generateMomentMessage(
        type: MomentMessage.MomentType,
        baseMoment: MomentMessage,
        snapshot: ConversationSnapshot,
        sleepSignal: SleepSignal,
        summary: String
    ) async -> MomentMessage {
        let context = MomentGenerationContext(
            type: type,
            baseMoment: baseMoment,
            snapshot: snapshot,
            sleepSignal: sleepSignal,
            momentSettings: momentSettings,
            analysisSummary: summary
        )

        do {
            let moment = try await environment.conversationGenerator.generateMomentMessage(context: context)
            currentConversationGenerationMode = moment.generationMode ?? .localDeterministicFallback
            await refreshNativeLLMDiagnostics()
            return moment
        } catch {
            print("[ConversationGenerator] momentGeneration unexpectedFailure reason=\(error.localizedDescription)")
            await refreshNativeLLMDiagnostics()
            return baseMoment
        }
    }

    private func reconcileMomentSchedule() {
        guard let analysis = currentAnalysis, let character = selectedCharacter else { return }
        Task {
            await environment.notificationScheduler.cancel(momentIDs: [analysis.bedtimeMoment.id, analysis.morningMoment.id])
            scheduledMoments = await environment.notificationScheduler.schedule(
                moments: enabledMoments(from: analysis),
                settings: momentSettings,
                characterID: character.id
            )
        }
    }

    private func enabledMoments(from analysis: MomentAnalysis) -> [MomentMessage] {
        [
            analysis.bedtimeMoment.withEnabled(momentSettings.isBedtimeMomentEnabled),
            analysis.morningMoment.withEnabled(momentSettings.isMorningMomentEnabled)
        ]
        .filter(\.isEnabled)
    }

    private func findMoment(id: UUID?) -> MomentMessage? {
        guard let id else { return nil }
        return momentCards().first { $0.id == id } ?? scheduledMoments.first { $0.id == id }
    }
}

private extension MomentAnalysis {
    func replacingMoments(bedtime: MomentMessage, morning: MomentMessage) -> MomentAnalysis {
        MomentAnalysis(
            id: id,
            snapshotID: snapshotID,
            sleepSignal: sleepSignal,
            worldInsight: worldInsight,
            characterInsight: characterInsight,
            relationshipInsight: relationshipInsight,
            lastSceneInsight: lastSceneInsight,
            emotionInsight: emotionInsight,
            toneDecision: toneDecision,
            bedtimeMoment: bedtime,
            morningMoment: morning,
            createdAt: createdAt
        )
    }
}
