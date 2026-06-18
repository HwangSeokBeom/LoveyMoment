import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    ForEach(store.characters) { character in
                        Button {
                            store.startChat(with: character)
                        } label: {
                            ChatListRow(
                                character: character,
                                lastMessage: store.messages(for: character).last?.text ?? character.openingScene,
                                relationshipStage: store.relationshipStage(for: character)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("채팅")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.white)
            Text("이어가던 대화를 다시 열어보세요")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
        }
        .padding(.bottom, 4)
    }
}

private struct ChatListRow: View {
    let character: CharacterProfile
    let lastMessage: String
    let relationshipStage: RelationshipStage

    var body: some View {
        HStack(spacing: 14) {
            CharacterPortraitView(character: character, size: 60, style: .mini)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(character.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    TagPill(text: relationshipStage.label, color: PoCTheme.secondary)
                    Spacer()
                }

                Text(lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PoCTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PoCTheme.stroke, lineWidth: 1)
                )
        )
    }
}
