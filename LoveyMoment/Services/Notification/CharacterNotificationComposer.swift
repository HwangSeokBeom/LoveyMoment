import Foundation

/// 캐릭터 알림의 표시 텍스트(title=캐릭터 이름, body=캐릭터 말투 메시지)를 만든다.
/// iOS는 알림이 발화되는 시점에 LLM을 실행할 수 없으므로, 예약 시점에 body를 미리 만들어
/// notification content와 ChatView 삽입 메시지가 동일한 CharacterNotificationPlan.body를 공유한다.
struct CharacterNotificationComposer {
    /// title은 항상 캐릭터 이름(카카오톡 스타일), body는 캐릭터 말투의 1~2문장.
    func compose(context: CharacterNotificationTriggerContext) -> (title: String, body: String) {
        let character = context.character
        let body = bodyText(
            avatarKey: character.generatedAvatarKey,
            name: character.name,
            type: context.triggerType,
            lastSceneSummary: context.lastSceneSummary
        )
        return (character.name, body)
    }

    private func bodyText(
        avatarKey: String,
        name: String,
        type: CharacterNotificationType,
        lastSceneSummary: String
    ) -> String {
        if let voiced = Self.voiceTable[avatarKey]?[type] {
            return voiced
        }
        return Self.genericBody(name: name, type: type)
    }

    /// generatedAvatarKey별 말투 템플릿. (한아/서윤/로이/카엘)
    private static let voiceTable: [String: [CharacterNotificationType: String]] = [
        "ice-boss": [
            .bedtimeMoment: "내일 오라고 했잖아. 피곤한 얼굴로 오면 바로 돌려보낼 거야.",
            .morningMoment: "일어났어? 오늘은 네가 먼저 올 줄 알았는데.",
            .delayedReply: "답 안 하는 거, 일부러야? 아니면 진짜 잠든 거야.",
            .relationshipTrigger: "방금 네 말, 그냥 넘기기엔 좀 신경 쓰이는데.",
            .sceneContinuation: "아까 하던 얘기, 아직 끝난 거 아니잖아.",
            .reengagement: "오늘은 안 오는 줄 알았어. 그래도 기다리고 있었어."
        ],
        "sunny-friend": [
            .bedtimeMoment: "오늘 하루도 고생했어. 자기 전에 딱 한마디만 하고 싶었어.",
            .morningMoment: "좋은 아침! 오늘은 어떤 하루가 될까, 같이 시작하자.",
            .delayedReply: "바쁜 거면 괜찮아. 그래도 나중에 한마디만 남겨줘.",
            .relationshipTrigger: "아까 네가 한 말, 계속 생각났어. 우리 좀 더 가까워진 것 같아.",
            .sceneContinuation: "우리 아까 이야기 이어서 하자. 나 아직 궁금한 게 많아.",
            .reengagement: "오랜만이야! 그동안 어떻게 지냈어? 보고 싶었어."
        ],
        "puppy-junior": [
            .bedtimeMoment: "선배 자요? 나 아직 안 졸린데… 잠깐만 얘기하면 안 돼요?",
            .morningMoment: "선배 일어났어요? 나 벌써 한참 전에 깼는데!",
            .delayedReply: "어라, 도망갔네. 나 아직 할 말 남았는데?",
            .relationshipTrigger: "방금 그 말, 진심이에요? 나 좀 두근거렸잖아요.",
            .sceneContinuation: "아까 하던 얘기 마저 해요! 나 끝까지 듣고 싶어요.",
            .reengagement: "선배 어디 갔었어요? 한참 기다렸단 말이에요."
        ],
        "nocturne-vampire": [
            .bedtimeMoment: "이제 곧 내 시간이군. 잠들기 전에 네 목소리를 듣고 싶었어.",
            .morningMoment: "해가 떴군. 너의 아침은 내 밤의 끝이야. 잘 잤나.",
            .delayedReply: "침묵도 대답이라고 생각해도 되는 건가.",
            .relationshipTrigger: "방금 그 한마디가 내 안의 무언가를 흔들어 놓았어.",
            .sceneContinuation: "끊긴 이야기는 어둠 속에 남겨두기 아깝지. 이어가자.",
            .reengagement: "오래 보이지 않더군. 네 부재는 생각보다 길게 느껴졌어."
        ]
    ]

    private static func genericBody(name: String, type: CharacterNotificationType) -> String {
        switch type {
        case .bedtimeMoment: return "자기 전에 네 생각이 났어. 오늘 하루는 어땠어?"
        case .morningMoment: return "좋은 아침. 오늘 하루도 같이 시작하고 싶었어."
        case .delayedReply: return "답장 기다리고 있었어. 바쁜 거면 천천히 와도 괜찮아."
        case .relationshipTrigger: return "아까 네가 한 말이 계속 마음에 남아 있어."
        case .sceneContinuation: return "아까 하던 이야기, 아직 끝나지 않았잖아."
        case .reengagement: return "오랜만이야. 다시 이야기 나누고 싶었어."
        }
    }
}
