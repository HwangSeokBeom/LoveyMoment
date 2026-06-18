import Foundation

struct AppEnvironment {
    let sleepSignalProvider: SleepSignalProviding
    let momentAnalyzer: MomentAnalyzing
    let notificationScheduler: MomentNotificationScheduling
    let characterNotificationScheduler: CharacterNotificationScheduling
    let conversationGenerator: ConversationGenerating
    let datingSignalAnalyzer: DatingSignalAnalyzing

    static let live = AppEnvironment(
        sleepSignalProvider: CompositeSleepSignalProvider(),
        momentAnalyzer: MockMomentAnalyzer(),
        notificationScheduler: LocalMomentNotificationScheduler(),
        characterNotificationScheduler: LocalCharacterNotificationScheduler(),
        conversationGenerator: CompositeConversationGenerator(),
        datingSignalAnalyzer: MockDatingSignalAnalyzer()
    )
}
