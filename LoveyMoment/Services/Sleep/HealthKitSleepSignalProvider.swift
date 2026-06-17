import Foundation
import HealthKit

final class HealthKitSleepSignalProvider {
    private let healthStore = HKHealthStore()

    func fetchSleepSignal(for snapshot: ConversationSnapshot) async throws -> SleepSignalFetchResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] isHealthDataAvailable=false")
            print("[HealthKit] fallback reason=simulatorOrUnavailable")
            throw HealthKitSleepError.unavailable
        }
        print("[HealthKit] isHealthDataAvailable=true")

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("[HealthKit] fallback reason=missingSleepType")
            throw HealthKitSleepError.missingSleepType
        }

        try await requestAuthorization(for: sleepType)
        print("[HealthKit] sleepQuery start range=14days")
        let samples = try await fetchRecentSleepSamples(type: sleepType)

        guard let rhythm = rhythm(from: samples, authorizationStatus: healthStore.authorizationStatus(for: sleepType).logName) else {
            print("[HealthKit] sleepQuery success sampleCount=0")
            print("[HealthKit] fallback reason=noSleepSamples")
            throw HealthKitSleepError.noSamples
        }

        print("[HealthKit] sleepQuery success sampleCount=\(samples.count)")
        print("[HealthKit] sleepSignal source=healthKitRealData bedtime=\(rhythm.bedtime) wakeTime=\(rhythm.wakeTime)")
        let signal = SleepSignal(
            estimatedBedtime: rhythm.bedtime,
            estimatedWakeTime: rhythm.wakeTime,
            source: .healthKit,
            confidence: samples.count >= 4 ? .high : .medium,
            explanation: "HealthKit Sleep Analysis 최근 기록 \(samples.count)개를 기준으로 취침/기상 리듬을 추정했습니다. 총 수면 \(rhythm.totalSleepMinutes)분, 출처: \(rhythm.sources.joined(separator: ", "))."
        )
        return SleepSignalFetchResult(
            signal: signal,
            diagnostics: SleepSignalDiagnostics(
                authorizationStatus: healthStore.authorizationStatus(for: sleepType).logName,
                source: .healthKitRealData,
                sampleCount: samples.count,
                lastSampleDate: rhythm.lastSampleDate,
                fallbackReason: nil,
                isSimulator: SleepSignalDiagnostics.isRunningOnSimulator,
                totalSleepMinutes: rhythm.totalSleepMinutes,
                estimatedBedtime: rhythm.bedtime,
                estimatedWakeTime: rhythm.wakeTime,
                dataSources: rhythm.sources,
                lastUpdatedAt: Date()
            )
        )
    }

    private func requestAuthorization(for sleepType: HKObjectType) async throws {
        print("[HealthKit] authorization=requestStart")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: [sleepType]) { success, error in
                if let error {
                    print("[HealthKit] authorization=failed reason=\(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                let status = self.healthStore.authorizationStatus(for: sleepType)
                print("[HealthKit] authorization=result success=\(success) status=\(status.logName)")
                if success {
                    continuation.resume()
                } else {
                    print("[HealthKit] fallback reason=authorizationDenied")
                    continuation.resume(throwing: HealthKitSleepError.authorizationDenied)
                }
            }
        }
    }

    private func fetchRecentSleepSamples(type: HKSampleType) async throws -> [HKCategorySample] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 120, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    print("[HealthKit] sleepQuery failed reason=\(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample] ?? [])
                    .filter { sample in
                        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM, .inBed:
                            return true
                        default:
                            return false
                        }
                    }
                continuation.resume(returning: sleepSamples)
            }
            healthStore.execute(query)
        }
    }

    private func rhythm(
        from samples: [HKCategorySample],
        authorizationStatus: String
    ) -> (bedtime: String, wakeTime: String, totalSleepMinutes: Int, lastSampleDate: Date?, sources: [String])? {
        guard !samples.isEmpty else { return nil }

        let sorted = samples.sorted { $0.startDate < $1.startDate }
        let latestDay = Calendar.current.startOfDay(for: sorted.last?.endDate ?? Date())
        let recent = sorted.filter { sample in
            Calendar.current.dateComponents([.day], from: latestDay, to: Calendar.current.startOfDay(for: sample.endDate)).day == 0
        }
        let target = recent.isEmpty ? sorted : recent

        guard let first = target.first, let last = target.last else { return nil }
        let asleepSamples = target.filter { sample in
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                return true
            default:
                return false
            }
        }
        let totalSleepMinutes = asleepSamples.reduce(0) { partial, sample in
            partial + Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
        }
        let sources = Array(Set(target.map { $0.sourceRevision.source.name })).sorted()
        let lastSampleDate = target.map(\.endDate).max()
        print("[HealthKit] authorizationStatus=\(authorizationStatus) totalSleepMinutes=\(totalSleepMinutes) sources=\(sources.joined(separator: ","))")
        return (
            Self.timeFormatter.string(from: first.startDate),
            Self.timeFormatter.string(from: last.endDate),
            totalSleepMinutes,
            lastSampleDate,
            sources
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum HealthKitSleepError: Error {
    case unavailable
    case missingSleepType
    case authorizationDenied
    case noSamples
}

final class CompositeSleepSignalProvider: SleepSignalProviding {
    private let healthKitProvider: HealthKitSleepSignalProvider
    private let fallbackProvider: MockSleepSignalProvider

    init(
        healthKitProvider: HealthKitSleepSignalProvider = HealthKitSleepSignalProvider(),
        fallbackProvider: MockSleepSignalProvider = MockSleepSignalProvider()
    ) {
        self.healthKitProvider = healthKitProvider
        self.fallbackProvider = fallbackProvider
    }

    func currentSleepSignalResult(for snapshot: ConversationSnapshot) async -> SleepSignalFetchResult {
        do {
            let result = try await healthKitProvider.fetchSleepSignal(for: snapshot)
            print("[Sleep][Composite] HealthKit signal selected for \(snapshot.character.name).")
            return result
        } catch {
            print("[Sleep][Composite] HealthKit unavailable or empty (\(error)). Falling back to MockSleepSignalProvider.")
            let fallback = await fallbackProvider.currentSleepSignalResult(for: snapshot)
            var diagnostics = fallback.diagnostics
            diagnostics.fallbackReason = fallbackReason(for: error)
            print("[HealthKit] fallback reason=\(diagnostics.fallbackReason ?? "unknown")")
            return SleepSignalFetchResult(signal: fallback.signal, diagnostics: diagnostics)
        }
    }

    private func fallbackReason(for error: Error) -> String {
        switch error {
        case HealthKitSleepError.unavailable:
            return SleepSignalDiagnostics.isRunningOnSimulator ? "simulatorOrUnavailable" : "healthDataUnavailable"
        case HealthKitSleepError.missingSleepType:
            return "missingSleepType"
        case HealthKitSleepError.authorizationDenied:
            return "authorizationDenied"
        case HealthKitSleepError.noSamples:
            return "noSleepSamples"
        default:
            return error.localizedDescription
        }
    }
}

private extension HKAuthorizationStatus {
    var logName: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .sharingDenied: return "sharingDenied"
        case .sharingAuthorized: return "sharingAuthorized"
        @unknown default: return "unknown"
        }
    }
}
