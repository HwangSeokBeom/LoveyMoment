import Foundation

/// Lovey Signal: 최애 캐릭터와의 대화에서 드러난 "관계 취향"을 분석해
/// 소개팅 추천 가능성을 보여주는 후속 확장 플로우의 데이터 모델.
/// 실제 매칭/연락/결제/위치 기능은 포함하지 않으며, 모든 후보는 예시 프로필이다.

// MARK: - Consent

/// 분석 시작 전에 받아야 하는 3가지 동의 항목.
struct DatingSignalConsent: Hashable {
    var agreesToConversationAnalysis = false
    var agreesToExampleProfilesOnly = false
    var agreesToNoRealMatching = false

    var isComplete: Bool {
        agreesToConversationAnalysis && agreesToExampleProfilesOnly && agreesToNoRealMatching
    }

    static let empty = DatingSignalConsent()
}

// MARK: - Conversation selection

/// 분석 대상으로 고른 최애 캐릭터 대화 한 건.
struct FavoriteConversationSelection: Identifiable, Hashable {
    let id: UUID
    let characterId: UUID
    let characterName: String
    let generatedAvatarKey: String
    let genreLabel: String
    let lastSceneSummary: String
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        characterId: UUID,
        characterName: String,
        generatedAvatarKey: String,
        genreLabel: String,
        lastSceneSummary: String,
        isSelected: Bool = false
    ) {
        self.id = id
        self.characterId = characterId
        self.characterName = characterName
        self.generatedAvatarKey = generatedAvatarKey
        self.genreLabel = genreLabel
        self.lastSceneSummary = lastSceneSummary
        self.isSelected = isSelected
    }
}

// MARK: - Preference profile

/// 관계 취향 축 하나. value(0...1)는 두 성향 사이에서 어디에 가까운지를 나타낸다.
struct RelationshipPreferenceAxis: Identifiable, Hashable {
    let id: UUID
    let title: String
    let lowLabel: String
    let highLabel: String
    /// 0 = lowLabel 쪽, 1 = highLabel 쪽.
    let value: Double
    let tendencyText: String

    init(
        id: UUID = UUID(),
        title: String,
        lowLabel: String,
        highLabel: String,
        value: Double,
        tendencyText: String
    ) {
        self.id = id
        self.title = title
        self.lowLabel = lowLabel
        self.highLabel = highLabel
        self.value = max(0, min(1, value))
        self.tendencyText = tendencyText
    }

    /// 게이지 표시용 정규화 값.
    var normalizedValue: Double { value }
}

/// 선택한 대화들에서 도출한 관계 취향 프로필.
struct RelationshipPreferenceProfile: Identifiable, Hashable {
    let id: UUID
    let headline: String
    let summary: String
    let keywordTags: [String]
    let axes: [RelationshipPreferenceAxis]
    let basedOnCharacterNames: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        headline: String,
        summary: String,
        keywordTags: [String],
        axes: [RelationshipPreferenceAxis],
        basedOnCharacterNames: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.keywordTags = keywordTags
        self.axes = axes
        self.basedOnCharacterNames = basedOnCharacterNames
        self.createdAt = createdAt
    }
}

// MARK: - Match candidates (example only)

/// 추천 후보가 내 취향과 맞닿는 이유 한 줄.
struct DatingMatchReason: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

/// 소개팅 추천 "예시" 프로필. 실제 인물이 아니며 추상 아바타로만 표현한다.
struct DatingMatchCandidate: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let ageLabel: String
    let oneLine: String
    let about: String
    /// 추상 그라데이션 아바타 색 키.
    let gradientKey: String
    /// 아바타에 표시할 이니셜.
    let initials: String
    let vibeTags: [String]
    let reasons: [DatingMatchReason]
    /// 항상 true: 실제 인물이 아닌 예시 프로필임을 명시.
    let isExampleProfile: Bool
    /// 내 취향 프로필과의 결을 정성적으로 표현한 라벨(퍼센트 아님).
    let affinityLabel: String

    init(
        id: UUID = UUID(),
        displayName: String,
        ageLabel: String,
        oneLine: String,
        about: String,
        gradientKey: String,
        initials: String,
        vibeTags: [String],
        reasons: [DatingMatchReason],
        affinityLabel: String,
        isExampleProfile: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.ageLabel = ageLabel
        self.oneLine = oneLine
        self.about = about
        self.gradientKey = gradientKey
        self.initials = initials
        self.vibeTags = vibeTags
        self.reasons = reasons
        self.affinityLabel = affinityLabel
        self.isExampleProfile = isExampleProfile
    }
}

// MARK: - Safety

/// 안전·윤리 안내 문구 묶음.
struct DatingSafetyNotice: Hashable {
    let title: String
    let points: [String]

    static let standard = DatingSafetyNotice(
        title: "안전하게 보는 법",
        points: [
            "여기 보이는 프로필은 모두 실제 인물이 아닌 예시예요.",
            "실제 만남·연락처 교환·결제·위치 공유는 제공하지 않아요.",
            "최애 캐릭터 대화에서 드러난 관계 취향만 분석해, 소개팅 추천이 가능한지 보여줘요.",
            "분석 결과는 취향 참고용이며, 사람을 단정하거나 진단하지 않아요."
        ]
    )
}
