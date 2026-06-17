import Foundation
import UserNotifications

@MainActor
final class LoveyMomentStore: ObservableObject {
    @Published var path: [AppRoute] = []
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

    private var hasRequestedNotificationPermissionInSession = false
    private var insertedMomentIDs: Set<UUID> = []
    private let environment: AppEnvironment
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
        path.append(.characterDetail(character.id))
    }

    func startChat(with character: CharacterProfile) {
        selectedCharacter = character
        momentSettings = character.sleepMomentSettings
        path.append(.chat)
    }

    func openDiagnostics() {
        refreshConversationGeneratorStatus()
        path.append(.diagnostics)
    }

    func bootstrapAppSession() {
        refreshConversationGeneratorStatus()
        requestNotificationAuthorizationIfNeeded(source: "appBootstrap")
    }

    func refreshConversationGeneratorStatus() {
        foundationModelsCompileAvailable = environment.conversationGenerator.compileAvailability
        nativeLLMAvailability = environment.conversationGenerator.availabilityStatus()
        currentConversationGenerationMode = nativeLLMAvailability.isAvailable ? .nativeFoundationModel : .localDeterministicFallback
        print("[ConversationGenerator] compileFoundationModels=\(foundationModelsCompileAvailable) availability=\(nativeLLMAvailability.displayText) selectedMode=\(currentConversationGenerationMode.rawValue)")
        Task {
            await refreshNativeLLMDiagnostics()
        }
    }

    func refreshNativeLLMDiagnostics() async {
        nativeLLMDiagnostics = await environment.conversationGenerator.nativeLLMDiagnosticsSnapshot()
    }

    func requestNotificationAuthorization() {
        requestNotificationAuthorizationIfNeeded(source: "manual")
    }

    func requestNotificationAuthorizationIfNeeded(source: String) {
        Task {
            let status = await environment.notificationScheduler.authorizationStatus()
            notificationAuthorizationStatus = status

            switch status {
            case .notDetermined:
                guard !hasRequestedNotificationPermissionInSession else {
                    print("[NotificationPermission] source=\(source) status=notDetermined skipRequest=sessionGuard")
                    return
                }
                hasRequestedNotificationPermissionInSession = true
                let granted = await environment.notificationScheduler.requestAuthorization()
                notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
                toastMessage = granted ? "알림 권한이 준비됐어요." : "알림 권한이 꺼져 있어요. 미리보기는 계속 사용할 수 있어요."
            case .authorized, .provisional, .ephemeral:
                print("[NotificationPermission] source=\(source) status=\(status.logName) skipRequest")
            case .denied:
                print("[NotificationPermission] source=\(source) status=denied showInAppGuide")
                toastMessage = "설정에서 알림을 허용하면 Moment 알림을 받을 수 있어요."
            @unknown default:
                print("[NotificationPermission] source=\(source) status=unknown showInAppGuide")
            }
        }
    }

    func refreshNotificationAuthorizationStatus() {
        Task {
            notificationAuthorizationStatus = await environment.notificationScheduler.authorizationStatus()
        }
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
            path.append(.momentAnalysis)
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
            path.append(.momentPreview)
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
            text: "Lovey Moment에서 이어짐",
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

        var messages = messagesByConversation[character.id] ?? []
        messages.append(ChatMessage(sender: .user, text: trimmed, createdAt: Date()))
        messagesByConversation[character.id] = messages
        isGeneratingReply = true
        refreshConversationGeneratorStatus()
        generationStatusText = currentConversationGenerationMode == .nativeFoundationModel ? "Native LLM generating..." : "Local generator..."

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
        generationStatusText = currentConversationGenerationMode == .nativeFoundationModel ? "Native LLM generating..." : "Local generator..."

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
        path = [.chat]
        insertPendingMomentIfNeeded()
        print("[DeepLink] navigate chat characterId=\(character.id)")
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
