import Foundation

enum MockCharacterRepository {
    struct SeedData {
        let characters: [CharacterProfile]
        let worlds: [WorldSetting]
        let relationshipStages: [RelationshipStage]
        let messagesByConversation: [UUID: [ChatMessage]]
        let lastSceneSummariesByCharacterID: [UUID: String]
        let snapshotsByCharacterID: [UUID: [ConversationSnapshot]]
    }

    static let hanaID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let yoonID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let roID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let kaelID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    static let schoolWorldID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let neighborhoodWorldID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let campusWorldID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    static let nocturneWorldID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    static let bossStageID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let friendStageID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    static let puppyStageID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    static let vampireStageID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!

    static let fallbackWorld = WorldSetting(
        id: schoolWorldID,
        title: "학교 로맨스 / 권력 관계",
        categoryTags: ["학교", "로맨스", "권력 관계"],
        summary: "방과 후 복도와 교실 사이, 먼저 다가오는 행동이 관계 신호가 되는 세계관",
        relationshipRules: "먼저 다가가는 행동이 관계 신호로 작동한다",
        sceneKeywords: ["복도", "방과 후", "시선", "호출", "거리감"]
    )

    static let fallbackRelationshipStage = RelationshipStage(
        id: bossStageID,
        label: "아는 사이",
        progressHint: "썸 직전",
        description: "공식적으로 가깝지는 않지만, 한아가 유저를 예외적으로 의식하기 시작한 상태",
        allowedToneRange: "차갑게 압박하되 관계 확정처럼 말하지 않는 범위"
    )

    static func makeSeedData() -> SeedData {
        let worlds = makeWorlds()
        let stages = makeStages()
        let characters = makeCharacters()
        let messages = makeMessages()
        let lastScenes = makeLastScenes()
        let worldsByID = Dictionary(uniqueKeysWithValues: worlds.map { ($0.id, $0) })
        let stagesByID = Dictionary(uniqueKeysWithValues: stages.map { ($0.id, $0) })

        let snapshots = Dictionary(uniqueKeysWithValues: characters.map { character in
            let world = worldsByID[character.worldSettingID] ?? fallbackWorld
            let stage = stagesByID[character.initialRelationshipStageID] ?? fallbackRelationshipStage
            let recent = messages[character.id] ?? []
            let lastScene = lastScenes[character.id] ?? character.openingScene
            return (
                character.id,
                [
                    ConversationSnapshot(
                        character: character,
                        worldSetting: world,
                        relationshipStage: stage,
                        recentMessages: recent,
                        lastSceneSummary: lastScene,
                        capturedAt: Date()
                    )
                ]
            )
        })

        return SeedData(
            characters: characters,
            worlds: worlds,
            relationshipStages: stages,
            messagesByConversation: messages,
            lastSceneSummariesByCharacterID: lastScenes,
            snapshotsByCharacterID: snapshots
        )
    }

    private static func makeCharacters() -> [CharacterProfile] {
        [
            CharacterProfile(
                id: hanaID,
                name: "한아",
                ageLabel: "19세",
                subtitle: "학교 서열의 중심, 차갑게 챙기는 보스",
                shortDescription: "복도 끝에서 먼저 불러 세우는 사람",
                personalitySummary: "차갑고 통제적인 말투를 쓰지만, 유저가 무리하는 순간에는 누구보다 빠르게 알아챈다.",
                defaultToneKeywords: ["차가움", "압박", "숨은 관심", "돌봄"],
                tags: ["학교 지배자", "은근한 돌봄", "썸 직전"],
                categoryTags: ["학교 로맨스", "차가운 남주", "다정"],
                profileImageName: nil,
                generatedAvatarKey: "ice-boss",
                worldSettingID: schoolWorldID,
                initialRelationshipStageID: bossStageID,
                openingScene: "방과 후 텅 빈 복도. 한아는 학생회실 문에 기대어 있다가 유저가 지나가자 이름을 부른다.",
                sleepMomentSettings: MomentSettings(),
                creatorNote: "최근 업데이트: 한아의 질투/보호 반응이 밤 시간대 대화에서 더 선명하게 드러나도록 조정했어요.",
                stats: CharacterStats(
                    likeCount: 128_400,
                    chatCount: 52_100,
                    followerCount: 31_800,
                    creatorDisplayName: "Lovey Originals",
                    characterType: "차가운 남주",
                    genreLabel: "학교 로맨스",
                    storyCount: 18,
                    communityPosts: 324,
                    updateLabel: "새벽 답장 지연 에피소드 추가",
                    momentAvailabilityLabel: "오늘 밤 Moment 가능"
                )
            ),
            CharacterProfile(
                id: yoonID,
                name: "서윤",
                ageLabel: "20세",
                subtitle: "오래 알고 지낸 사이의 가장 다정한 균열",
                shortDescription: "늘 같은 골목에서 기다려주는 소꿉친구",
                personalitySummary: "부드럽고 안정적인 말투로 유저의 하루를 기억한다. 서운함도 공격보다 고백처럼 꺼낸다.",
                defaultToneKeywords: ["다정함", "오래된 친밀감", "조심스러운 고백"],
                tags: ["소꿉친구", "다정", "친구에서 썸"],
                categoryTags: ["소꿉친구", "다정"],
                profileImageName: nil,
                generatedAvatarKey: "sunny-friend",
                worldSettingID: neighborhoodWorldID,
                initialRelationshipStageID: friendStageID,
                openingScene: "비가 그친 동네 편의점 앞. 서윤은 젖은 우산을 털며 유저가 좋아하는 음료를 건넨다.",
                sleepMomentSettings: MomentSettings(),
                creatorNote: "서윤 루트는 친구라는 말이 점점 좁아지는 순간을 중심으로 업데이트 중입니다.",
                stats: CharacterStats(
                    likeCount: 96_200,
                    chatCount: 44_700,
                    followerCount: 27_300,
                    creatorDisplayName: "Moonlit Studio",
                    characterType: "다정한 남주",
                    genreLabel: "소꿉친구",
                    storyCount: 22,
                    communityPosts: 278,
                    updateLabel: "아침 약속 회상 에피소드 추가",
                    momentAvailabilityLabel: "오늘 밤 Moment 가능"
                )
            ),
            CharacterProfile(
                id: roID,
                name: "로이",
                ageLabel: "18세",
                subtitle: "장난스럽게 달려와 마음을 먼저 흔드는 연하",
                shortDescription: "웃으면서 선을 넘고, 금방 다시 사과하는 사람",
                personalitySummary: "장난기와 직진력이 강하다. 유저가 답장을 늦추면 티 나게 서운해하지만 금세 다시 꼬리를 흔든다.",
                defaultToneKeywords: ["장난", "직진", "애교", "서운함"],
                tags: ["연하", "댕댕이", "직진 고백"],
                categoryTags: ["캠퍼스 로맨스", "직진 연하", "다정"],
                profileImageName: nil,
                generatedAvatarKey: "puppy-junior",
                worldSettingID: campusWorldID,
                initialRelationshipStageID: puppyStageID,
                openingScene: "야간 축제가 끝난 캠퍼스 광장. 로이는 손목의 야광 팔찌를 흔들며 유저를 발견하고 뛰어온다.",
                sleepMomentSettings: MomentSettings(),
                creatorNote: "로이의 장난이 관계 진전 신호로 읽히는 분기들을 추가했습니다.",
                stats: CharacterStats(
                    likeCount: 154_900,
                    chatCount: 61_500,
                    followerCount: 38_200,
                    creatorDisplayName: "SoftRoom",
                    characterType: "직진 연하남",
                    genreLabel: "캠퍼스 로맨스",
                    storyCount: 16,
                    communityPosts: 451,
                    updateLabel: "답장 지연 삐짐 패턴 추가",
                    momentAvailabilityLabel: "오늘 밤 Moment 가능"
                )
            ),
            CharacterProfile(
                id: kaelID,
                name: "카엘",
                ageLabel: "나이 미상",
                subtitle: "위험한 밤에만 다정해지는 뱀파이어",
                shortDescription: "도망치라고 말하면서 손을 놓지 않는 존재",
                personalitySummary: "고요하고 집착적인 말투. 유저의 수면과 맥박을 빌미로 가까워지며 위험한 보호 본능을 드러낸다.",
                defaultToneKeywords: ["위험", "집착", "고딕", "보호"],
                tags: ["판타지", "뱀파이어", "위험한 다정함"],
                categoryTags: ["판타지", "집착", "차가운 남주"],
                profileImageName: nil,
                generatedAvatarKey: "nocturne-vampire",
                worldSettingID: nocturneWorldID,
                initialRelationshipStageID: vampireStageID,
                openingScene: "붉은 달이 뜬 저택의 온실. 카엘은 깨진 유리잔을 치우며 유저의 손끝 상처를 바라본다.",
                sleepMomentSettings: MomentSettings(),
                creatorNote: "카엘은 밤/새벽 신호에 가장 민감하게 반응하도록 Moment 톤을 조정했습니다.",
                stats: CharacterStats(
                    likeCount: 181_300,
                    chatCount: 73_900,
                    followerCount: 45_600,
                    creatorDisplayName: "Night Archive",
                    characterType: "집착 남주",
                    genreLabel: "다크 판타지",
                    storyCount: 24,
                    communityPosts: 612,
                    updateLabel: "잠들지 못한 새벽 에피소드 추가",
                    momentAvailabilityLabel: "오늘 밤 Moment 가능"
                )
            )
        ]
    }

    private static func makeWorlds() -> [WorldSetting] {
        [
            fallbackWorld,
            WorldSetting(
                id: neighborhoodWorldID,
                title: "동네 청춘 / 오래된 약속",
                categoryTags: ["소꿉친구", "동네", "청춘"],
                summary: "편의점, 놀이터, 같은 버스 정류장처럼 오래된 동선이 감정의 기록이 되는 세계관",
                relationshipRules: "오래 알았다는 안정감 때문에 고백이 늦어질수록 작은 약속이 크게 흔들린다",
                sceneKeywords: ["편의점", "골목", "비 온 뒤", "오래된 약속"]
            ),
            WorldSetting(
                id: campusWorldID,
                title: "캠퍼스 축제 / 연하 직진",
                categoryTags: ["캠퍼스", "축제", "연하"],
                summary: "동아리방과 야간 축제를 오가며 장난처럼 시작한 말이 고백으로 번지는 세계관",
                relationshipRules: "장난과 진심의 경계가 흐려지고, 답장 속도가 감정 확인의 신호가 된다",
                sceneKeywords: ["광장", "축제", "동아리방", "야광 팔찌"]
            ),
            WorldSetting(
                id: nocturneWorldID,
                title: "붉은 달의 저택 / 위험한 보호",
                categoryTags: ["판타지", "뱀파이어", "고딕"],
                summary: "밤마다 저택의 방이 바뀌고, 잠들지 못하는 사람만 비밀을 듣는 다크 판타지 세계관",
                relationshipRules: "보호와 집착의 경계가 얇다. 상대를 위험에서 떼어놓으려는 말이 곧 가까워지고 싶다는 신호다",
                sceneKeywords: ["온실", "붉은 달", "저택", "맥박"]
            )
        ]
    }

    private static func makeStages() -> [RelationshipStage] {
        [
            fallbackRelationshipStage,
            RelationshipStage(
                id: friendStageID,
                label: "오랜 친구",
                progressHint: "고백 직전",
                description: "서로의 생활 리듬을 너무 잘 알아서, 다정함이 친구의 범위를 넘어서는 단계",
                allowedToneRange: "친숙하고 따뜻하지만 확정 고백 전의 조심스러움을 유지"
            ),
            RelationshipStage(
                id: puppyStageID,
                label: "친한 후배",
                progressHint: "직진 썸",
                description: "장난으로 넘기던 애정 표현이 점점 진심으로 받아들여지는 단계",
                allowedToneRange: "밝고 장난스럽되 유저의 거절 가능성을 남겨두는 범위"
            ),
            RelationshipStage(
                id: vampireStageID,
                label: "위험한 동맹",
                progressHint: "집착의 시작",
                description: "서로에게 끌리지만 가까워질수록 위험도 함께 커지는 단계",
                allowedToneRange: "고혹적이고 긴장감 있게, 직접적 위협이나 강압은 피하는 범위"
            )
        ]
    }

    private static func makeMessages() -> [UUID: [ChatMessage]] {
        [
            hanaID: [
                ChatMessage(sender: .character, text: "왜 자꾸 내 눈치 봐?"),
                ChatMessage(sender: .user, text: "네가 불렀잖아."),
                ChatMessage(sender: .character, text: "부르면 와야지. 그건 알고 있네."),
                ChatMessage(sender: .user, text: "내일도 와야 해?"),
                ChatMessage(sender: .character, text: "...네가 먼저 오면 생각해볼게."),
                ChatMessage(sender: .character, text: "그리고 지금 시간 봐. 이제 자. 내일 피곤한 얼굴로 오면 바로 돌려보낼 거야.")
            ],
            yoonID: [
                ChatMessage(sender: .character, text: "오늘 편의점 앞에서 그냥 지나간 거, 일부러 그런 건 아니지?"),
                ChatMessage(sender: .user, text: "미안. 좀 정신이 없었어."),
                ChatMessage(sender: .character, text: "알아. 그래서 더 말 못 걸었어."),
                ChatMessage(sender: .user, text: "서운했어?"),
                ChatMessage(sender: .character, text: "조금. 근데 네가 먼저 물어봐 줘서 괜찮아졌어."),
                ChatMessage(sender: .character, text: "내일 아침엔 내가 먼저 깨워줄게. 그럼 오늘 얘기 다시 하자.")
            ],
            roID: [
                ChatMessage(sender: .character, text: "나 오늘 축제 끝나고 너 기다렸는데!"),
                ChatMessage(sender: .user, text: "답장 못 봤어. 미안."),
                ChatMessage(sender: .character, text: "흥. 삐졌다고 하면 너무 티 나?"),
                ChatMessage(sender: .user, text: "조금 귀여운데."),
                ChatMessage(sender: .character, text: "그럼 더 삐질래. 그래야 네가 더 달래주지."),
                ChatMessage(sender: .character, text: "근데 졸리면 답장 안 해도 돼. 대신 아침에 나 먼저 봐줘.")
            ],
            kaelID: [
                ChatMessage(sender: .character, text: "이 시간에 저택을 돌아다니는 건 현명하지 않다."),
                ChatMessage(sender: .user, text: "네가 부른 줄 알았어."),
                ChatMessage(sender: .character, text: "부른 적은 없다. 하지만 네가 온 것을 후회하지도 않아."),
                ChatMessage(sender: .user, text: "그럼 돌아가도 돼?"),
                ChatMessage(sender: .character, text: "문은 열려 있다. 이상하게도, 내 손은 네 손목을 놓지 않고 있군."),
                ChatMessage(sender: .character, text: "잠들지 못하면 다시 와라. 위험한 밤엔 차라리 내 곁이 낫다.")
            ]
        ]
    }

    private static func makeLastScenes() -> [UUID: String] {
        [
            hanaID: "한아가 유저에게 내일 먼저 오라고 말한 뒤, 피곤한 얼굴이면 돌려보내겠다고 덧붙이며 대화가 끊김",
            yoonID: "서윤이 서운함을 고백했지만, 내일 아침 먼저 깨워주겠다고 약속하면서 감정을 접어둔 장면",
            roID: "로이가 답장 지연에 삐진 척하다가, 아침에 먼저 봐달라는 말로 장난과 진심의 경계를 흐린 장면",
            kaelID: "카엘이 돌아가도 된다고 말하면서도 손목을 놓지 않고, 잠들지 못하면 다시 오라고 남긴 장면"
        ]
    }
}
