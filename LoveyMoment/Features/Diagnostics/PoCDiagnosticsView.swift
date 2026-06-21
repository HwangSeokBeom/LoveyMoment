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
                DiagnosticRow(title: "Engine mode", value: store.conversationEngineMode.displayName)
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

                Picker("Engine mode", selection: Binding(
                    get: { store.conversationEngineMode },
                    set: { store.setConversationEngineMode($0) }
                )) {
                    ForEach(ConversationEngineMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        store.checkNativeLLMAvailability()
                    } label: {
                        Label("Check Native LLM Availability", systemImage: "cpu")
                    }
                    .buttonStyle(DiagnosticButtonStyle())

                    Button {
                        store.runNativeLLMSimpleKoreanTest()
                    } label: {
                        Label(
                            store.isRunningNativeLLMDiagnosticsTest ? "Testing..." : "Test Native LLM Simple Korean Reply",
                            systemImage: "text.bubble.fill"
                        )
                    }
                    .buttonStyle(DiagnosticButtonStyle())
                    .disabled(store.isRunningNativeLLMDiagnosticsTest)

                    Button {
                        store.runNativeLLMCharacterPromptTest()
                    } label: {
                        Label(
                            store.isRunningNativeLLMDiagnosticsTest ? "Testing..." : "Test Native LLM Character Prompt",
                            systemImage: "person.bubble.fill"
                        )
                    }
                    .buttonStyle(DiagnosticButtonStyle())
                    .disabled(store.isRunningNativeLLMDiagnosticsTest)

                    Button {
                        store.runChatEngineAutoModeScenario()
                    } label: {
                        Label(
                            store.isRunningConversationDiagnostics ? "Running..." : "Test Chat Engine Auto Mode Scenario",
                            systemImage: "arrow.triangle.branch"
                        )
                    }
                    .buttonStyle(DiagnosticButtonStyle())
                    .disabled(store.isRunningConversationDiagnostics)

                    Button {
                        store.runDeterministicFallbackScenario()
                    } label: {
                        Label(
                            store.isRunningConversationDiagnostics ? "Running..." : "Test Deterministic Fallback Scenario",
                            systemImage: "arrow.uturn.down"
                        )
                    }
                    .buttonStyle(DiagnosticButtonStyle())
                    .disabled(store.isRunningConversationDiagnostics)

                    Button {
                        store.runConversationDebugHarness()
                    } label: {
                        Label(
                            store.isRunningConversationDiagnostics ? "Running..." : "Run 17-turn Chat Flow Scenarios",
                            systemImage: "checklist.checked"
                        )
                    }
                    .buttonStyle(DiagnosticButtonStyle())
                    .disabled(store.isRunningConversationDiagnostics)
                }

                if let summary = store.conversationDebugSummary {
                    DiagnosticRow(title: "Conversation diagnostics", value: summary)
                }
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

private struct DiagnosticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
    }
}
