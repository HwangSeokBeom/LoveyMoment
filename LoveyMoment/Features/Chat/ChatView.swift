import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var draftText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            if let character = store.selectedCharacter {
                chatContent(character: character)
            } else {
                ContentUnavailableView("선택된 캐릭터가 없어요", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(store.selectedCharacter?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.insertPendingMomentIfNeeded()
        }
    }

    private func chatContent(character: CharacterProfile) -> some View {
        let world = store.world(for: character)
        let relationship = store.relationshipStage(for: character)
        let messages = store.messages(for: character)

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChatHeaderView(character: character, world: world, relationshipStage: relationship)

                    LastSceneSummaryView(summary: store.lastSceneSummary(for: character))

                    ScenarioStripView { scenario in
                        store.generateScenario(scenario)
                    }

                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message, character: character)
                                .id(message.id)
                        }
                    }
                    .padding(.top, 2)

                    if store.isGeneratingReply {
                        TypingIndicatorView(
                            character: character,
                            statusText: store.generationStatusText ?? "답장을 쓰는 중…"
                        )
                    }

                    if store.isAnalyzing {
                        InlineNoticeView(text: "수면 리듬과 대화를 살펴보는 중…", icon: "waveform.path.ecg")
                    }
                }
                .padding(18)
                .padding(.bottom, 118)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isInputFocused = false
                }
            )
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    draftText: $draftText,
                    isInputFocused: $isInputFocused,
                    canSend: !store.isGeneratingReply,
                    canAnalyze: !store.isAnalyzing && !store.isGeneratingReply,
                    sendAction: sendDraft,
                    analyzeAction: store.generateMomentAnalysis
                )
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func sendDraft() {
        store.sendUserMessage(draftText)
        draftText = ""
    }
}

struct ChatHeaderView: View {
    let character: CharacterProfile
    let world: WorldSetting
    let relationshipStage: RelationshipStage

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CharacterAvatarView(character: character, size: 54, showsBadge: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(character.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(world.sceneKeywords.first ?? world.title) · 지금 · \(relationshipStage.progressHint)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    TagPill(text: relationshipStage.label, color: PoCTheme.primary)
                }

                Text(character.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LastSceneSummaryView: View {
    let summary: String

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                SectionEyebrow(text: "마지막 장면")
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ScenarioStripView: View {
    let action: (ConversationScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(text: "상황 태그")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ConversationScenario.allCases) { scenario in
                        Button {
                            action(scenario)
                        } label: {
                            Label(scenario.title, systemImage: scenario.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    let character: CharacterProfile

    private var isUser: Bool {
        message.sender == .user
    }

    var body: some View {
        if message.sender == .system {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Label(message.text, systemImage: "bell.badge.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PoCTheme.primary)
                    Text("알림에서 이어진 대화")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.42))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PoCTheme.primary.opacity(0.12))
                )
                Spacer()
            }
        } else {
            HStack(alignment: .bottom) {
                if isUser { Spacer(minLength: 52) }

                if !isUser {
                    CharacterPortraitView(character: character, size: 36, style: .message)
                        .padding(.bottom, 18)
                }

                VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                    if message.isMomentInserted {
                        Label("Lovey Moment에서 이어짐", systemImage: "bell.badge.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PoCTheme.primary)
                    }

                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(bubbleColor)
                        )

                    footer
                }
                .frame(maxWidth: 292, alignment: isUser ? .trailing : .leading)

                if !isUser { Spacer(minLength: 52) }
            }
        }
    }

    private var bubbleColor: Color {
        if message.isMomentInserted {
            return PoCTheme.primary.opacity(0.30)
        }
        return isUser ? PoCTheme.userBubble : PoCTheme.characterBubble
    }

    @ViewBuilder
    private var footer: some View {
        if isUser {
            Text("나")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
        } else {
            Text(character.name)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}

private struct TypingIndicatorView: View {
    let character: CharacterProfile
    let statusText: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            CharacterPortraitView(character: character, size: 42, style: .mini)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(character.name)가 답장을 쓰는 중")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(PoCTheme.primary.opacity(0.55 + Double(index) * 0.12))
                            .frame(width: 6, height: 6)
                    }

                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.52))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct ChatInputBar: View {
    @Binding var draftText: String
    var isInputFocused: FocusState<Bool>.Binding
    let canSend: Bool
    let canAnalyze: Bool
    let sendAction: () -> Void
    let analyzeAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // 키보드가 내려가 있을 때만 보이는 컴팩트 Moment 액션. 입력을 가리지 않는다.
            if !isInputFocused.wrappedValue {
                Button(action: analyzeAction) {
                    Label(canAnalyze ? "오늘 밤 이 장면으로 Moment 만들기" : "Moment 만드는 중", systemImage: "sparkles")
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(canAnalyze ? PoCTheme.primary : .white.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(PoCTheme.primary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAnalyze)
            }

            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)

                TextField("메시지 입력", text: $draftText, axis: .vertical)
                    .focused(isInputFocused)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )

                // 키보드가 올라온 동안에는 Moment를 작은 아이콘 버튼으로만 노출.
                if isInputFocused.wrappedValue {
                    Button(action: analyzeAction) {
                        Image(systemName: "sparkles")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(canAnalyze ? Color.black.opacity(0.82) : .white.opacity(0.35))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(canAnalyze ? PoCTheme.primary.opacity(0.85) : Color.white.opacity(0.10)))
                    }
                    .disabled(!canAnalyze)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Moment 만들기")
                }

                Button(action: sendAction) {
                    Image(systemName: "paperplane.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(!canSubmit ? .white.opacity(0.35) : Color.black.opacity(0.82))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(!canSubmit ? Color.white.opacity(0.10) : PoCTheme.primary))
                }
                .disabled(!canSubmit)
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.72))
        .animation(.easeInOut(duration: 0.18), value: isInputFocused.wrappedValue)
    }

    private var canSubmit: Bool {
        canSend && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
