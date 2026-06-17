import Foundation

struct AppEnvironment {
    let sleepSignalProvider: SleepSignalProviding
    let momentAnalyzer: MomentAnalyzing
    let notificationScheduler: MomentNotificationScheduling
    let conversationGenerator: ConversationGenerating

    static let live = AppEnvironment(
        sleepSignalProvider: CompositeSleepSignalProvider(),
        momentAnalyzer: MockMomentAnalyzer(),
        notificationScheduler: LocalMomentNotificationScheduler(),
        conversationGenerator: CompositeConversationGenerator()
    )
}
