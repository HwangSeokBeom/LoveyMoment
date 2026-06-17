import SwiftUI

struct PoCDiagnosticsView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    nativeLLMCard
                    healthKitCard
                    notificationCard
                }
                .padding(18)
            }
        }
        .navigationTitle("PoC Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.refreshConversationGeneratorStatus()
            store.refreshNotificationAuthorizationStatus()
            Task {
                await store.refreshNativeLLMDiagnostics()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PoC Diagnostics")
                .font(.title.weight(.heavy))
                .foregroundStyle(.white)
            Text("Native LLM, HealthKit, local notification 딥링크 상태를 평가용으로 노출합니다.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nativeLLMCard: some View {
        let diagnostics = store.nativeLLMDiagnostics
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if let character = store.selectedCharacter {
                        CharacterPortraitView(character: character, size: 76)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionEyebrow(text: "Native LLM")
                        TagPill(
                            text: diagnostics.lastGenerationMode.badgeText,
                            color: diagnostics.lastGenerationMode == .nativeFoundationModel ? PoCTheme.secondary : PoCTheme.primary
                        )
                    }

                    Spacer()
                }

                DiagnosticRow(title: "iOS version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                DiagnosticRow(title: "Device", value: SleepSignalDiagnostics.isRunningOnSimulator ? "Simulator" : "Device")
                DiagnosticRow(title: "FoundationModels compile", value: diagnostics.canImportFoundationModels ? "true" : "\(store.foundationModelsCompileAvailable)")
                DiagnosticRow(title: "OS available", value: diagnostics.osAvailable ? "true" : "false")
                DiagnosticRow(title: "Runtime availability", value: store.nativeLLMAvailability.displayText)
                DiagnosticRow(title: "Current mode", value: store.currentConversationGenerationMode.displayName)
                DiagnosticRow(title: "Last generation mode", value: diagnostics.lastGenerationMode.displayName)
                DiagnosticRow(title: "Last native success", value: diagnostics.lastGenerationSucceeded ? "true" : "false")
                DiagnosticRow(title: "Last native success time", value: diagnostics.lastGenerationSucceeded ? formatted(diagnostics.lastGenerationCompletedAt) : "none")
                DiagnosticRow(title: "Last started", value: formatted(diagnostics.lastGenerationStartedAt))
                DiagnosticRow(title: "Last completed", value: formatted(diagnostics.lastGenerationCompletedAt))
                DiagnosticRow(title: "Context chars", value: "\(diagnostics.contextCharacterCount)")
                DiagnosticRow(title: "Generated chars", value: "\(diagnostics.lastGeneratedCharacterCount)")
                DiagnosticRow(title: "Last failure reason", value: diagnostics.lastFailureReason ?? "none")
                DiagnosticRow(title: "Last fallback reason", value: diagnostics.lastFallbackReason ?? "none")
                DiagnosticRow(title: "Last generated preview", value: diagnostics.lastGeneratedTextPreview ?? "none")
                DiagnosticRow(title: "No external API", value: diagnostics.noExternalAPI ? "true" : "false")
            }
        }
    }

    private func formatted(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "none"
    }

    private var healthKitCard: some View {
        let diagnostics = store.currentSleepDiagnostics
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "HealthKit")
                DiagnosticRow(title: "HealthKit availability", value: diagnostics.isSimulator ? "simulatorOrUnavailable" : "deviceCheckRequired")
                DiagnosticRow(title: "Authorization", value: diagnostics.authorizationStatus)
                DiagnosticRow(title: "Sleep source", value: diagnostics.source.displayName)
                DiagnosticRow(title: "Sample count", value: "\(diagnostics.sampleCount)")
                DiagnosticRow(title: "Total sleep", value: "\(diagnostics.totalSleepMinutes) min")
                DiagnosticRow(title: "Bedtime", value: diagnostics.estimatedBedtime ?? "none")
                DiagnosticRow(title: "Wake time", value: diagnostics.estimatedWakeTime ?? "none")
                DiagnosticRow(title: "Fallback reason", value: diagnostics.fallbackReason ?? "none")
                DiagnosticRow(title: "Last sample", value: diagnostics.lastSampleDate?.formatted(date: .abbreviated, time: .shortened) ?? "none")
            }
        }
    }

    private var notificationCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "Local Notification")
                DiagnosticRow(title: "Authorization", value: store.notificationAuthorizationStatus.logName)
                DiagnosticRow(title: "Last scheduled id", value: store.lastScheduledNotificationID ?? "none")
                DiagnosticRow(title: "Last route", value: routeText)
                DiagnosticRow(title: "Last inserted moment", value: store.lastInsertedMomentID?.uuidString ?? "none")
                DiagnosticRow(title: "Pending route", value: store.pendingNotificationRoute?.id ?? "none")
            }
        }
    }

    private var routeText: String {
        guard let route = store.lastNotificationRoute else { return "none" }
        return "characterId=\(route.characterId.uuidString) momentId=\(route.momentId.uuidString) target=\(route.deepLinkTarget)"
    }
}

private struct DiagnosticRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
