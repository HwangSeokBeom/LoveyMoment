import SwiftUI

struct CharacterAvatarView: View {
    let character: CharacterProfile
    var size: CGFloat = 88
    var showsBadge = true

    var body: some View {
        CharacterPortraitView(character: character, size: size)
            .accessibilityLabel("\(character.name) 캐릭터 portrait")
    }
}
