import Foundation

struct MockSleepSignalProvider: SleepSignalProviding {
    func currentSleepSignalResult(for snapshot: ConversationSnapshot) async -> SleepSignalFetchResult {
        print("[Sleep][Mock] Using fallback sleep rhythm for \(snapshot.character.name)")
        let signal = SleepSignal(
            estimatedBedtime: "23:40",
            estimatedWakeTime: "07:20",
            source: .mock,
            confidence: .medium,
            explanation: "HealthKit을 사용할 수 없거나 데이터가 없어서 PoC 검증용 수면 리듬을 사용합니다."
        )
        return SleepSignalFetchResult(
            signal: signal,
            diagnostics: SleepSignalDiagnostics(
                authorizationStatus: "unavailable",
                source: .mockFallback,
                sampleCount: 0,
                lastSampleDate: nil,
                fallbackReason: "mockProvider",
                isSimulator: SleepSignalDiagnostics.isRunningOnSimulator,
                totalSleepMinutes: 0,
                estimatedBedtime: signal.estimatedBedtime,
                estimatedWakeTime: signal.estimatedWakeTime,
                dataSources: ["MockSleepSignalProvider"],
                lastUpdatedAt: Date()
            )
        )
    }
}
