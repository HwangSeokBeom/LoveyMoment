import Foundation

/// 결정적(deterministic) 관계 취향 분석기. 시뮬레이터/오프라인에서도 동일하게 동작하도록
/// 캐릭터별 고정 성향 벡터를 평균내어 취향 프로필을 만든다.
///
/// 4개 취향 축(각 0...1):
///   tempo      대화 온도: 0 차분/편안 ↔ 1 설렘/긴장감
///   pace       관계 속도: 0 천천히 신뢰 ↔ 1 빠른 친밀감
///   playfulness 표현 방식: 0 다정한 직진 ↔ 1 장난스러운 밀당
///   immersion  몰입 성향: 0 잔잔한 일상 ↔ 1 세계관 몰입
struct MockDatingSignalAnalyzer: DatingSignalAnalyzing {
    struct Vector {
        let tempo: Double
        let pace: Double
        let playfulness: Double
        let immersion: Double
    }

    /// generatedAvatarKey -> 성향 벡터.
    private func vector(for avatarKey: String) -> Vector {
        switch avatarKey {
        case "ice-boss": // 한아 — 긴장감, 리드, 차갑지만 보호하는 타입
            return Vector(tempo: 0.85, pace: 0.4, playfulness: 0.35, immersion: 0.55)
        case "sunny-friend": // 서윤 — 다정함, 안정감, 친구 같은 거리감
            return Vector(tempo: 0.3, pace: 0.45, playfulness: 0.2, immersion: 0.3)
        case "puppy-junior": // 로이 — 장난스러움, 빠른 친밀감, 티키타카
            return Vector(tempo: 0.6, pace: 0.85, playfulness: 0.85, immersion: 0.35)
        case "nocturne-vampire": // 카엘 — 몰입형 세계관, 느린 신뢰, 진중함
            return Vector(tempo: 0.7, pace: 0.2, playfulness: 0.3, immersion: 0.9)
        default:
            return Vector(tempo: 0.5, pace: 0.5, playfulness: 0.5, immersion: 0.5)
        }
    }

    func analyzePreference(from selections: [FavoriteConversationSelection]) -> RelationshipPreferenceProfile {
        let chosen = selections.filter(\.isSelected)
        let vectors = chosen.map { vector(for: $0.generatedAvatarKey) }
        let count = max(vectors.count, 1)

        let tempo = vectors.map(\.tempo).reduce(0, +) / Double(count)
        let pace = vectors.map(\.pace).reduce(0, +) / Double(count)
        let playfulness = vectors.map(\.playfulness).reduce(0, +) / Double(count)
        let immersion = vectors.map(\.immersion).reduce(0, +) / Double(count)

        let axes = [
            RelationshipPreferenceAxis(
                title: "대화 온도",
                lowLabel: "차분하고 편안한",
                highLabel: "설레고 긴장감 있는",
                value: tempo,
                tendencyText: tempoTendency(tempo)
            ),
            RelationshipPreferenceAxis(
                title: "관계 속도",
                lowLabel: "천천히 쌓는 신뢰",
                highLabel: "빠르게 가까워지는",
                value: pace,
                tendencyText: paceTendency(pace)
            ),
            RelationshipPreferenceAxis(
                title: "표현 방식",
                lowLabel: "다정한 직진",
                highLabel: "장난스러운 밀당",
                value: playfulness,
                tendencyText: playfulnessTendency(playfulness)
            ),
            RelationshipPreferenceAxis(
                title: "몰입 성향",
                lowLabel: "잔잔한 일상 공유",
                highLabel: "깊은 세계관 몰입",
                value: immersion,
                tendencyText: immersionTendency(immersion)
            )
        ]

        return RelationshipPreferenceProfile(
            headline: headline(tempo: tempo, pace: pace, playfulness: playfulness, immersion: immersion),
            summary: summary(tempo: tempo, pace: pace, playfulness: playfulness, immersion: immersion, names: chosen.map(\.characterName)),
            keywordTags: keywordTags(tempo: tempo, pace: pace, playfulness: playfulness, immersion: immersion),
            axes: axes,
            basedOnCharacterNames: chosen.map(\.characterName)
        )
    }

    func recommendedCandidates(for profile: RelationshipPreferenceProfile) -> [DatingMatchCandidate] {
        MockDatingCandidateRepository.candidates(for: profile)
    }

    // MARK: - Tendency text

    private func tempoTendency(_ value: Double) -> String {
        if value >= 0.66 { return "설레는 긴장감과 끌림이 또렷한 대화를 더 좋아하는 편이에요." }
        if value <= 0.4 { return "편안하고 잔잔하게 이어지는 대화에서 더 안정감을 느끼는 편이에요." }
        return "설렘과 편안함 사이에서 균형을 즐기는 편이에요."
    }

    private func paceTendency(_ value: Double) -> String {
        if value >= 0.66 { return "마음이 통하면 빠르게 가까워지는 흐름을 즐기는 편이에요." }
        if value <= 0.4 { return "시간을 들여 천천히 신뢰를 쌓는 관계를 더 편안해하는 편이에요." }
        return "상황에 따라 속도를 맞춰가는 유연한 편이에요." }

    private func playfulnessTendency(_ value: Double) -> String {
        if value >= 0.66 { return "장난과 티키타카가 오가는 가벼운 밀당을 즐기는 편이에요." }
        if value <= 0.4 { return "돌려 말하기보다 다정하게 직진하는 표현을 더 좋아하는 편이에요." }
        return "다정함과 장난을 상황에 맞게 섞어 쓰는 편이에요." }

    private func immersionTendency(_ value: Double) -> String {
        if value >= 0.66 { return "둘만의 분위기·서사에 깊이 몰입하는 관계에 끌리는 편이에요." }
        if value <= 0.4 { return "특별한 설정보다 소소한 일상을 함께 나누는 걸 더 좋아하는 편이에요." }
        return "일상과 몰입을 자연스럽게 오가는 편이에요." }

    // MARK: - Headline / summary / tags

    private func headline(tempo: Double, pace: Double, playfulness: Double, immersion: Double) -> String {
        if tempo >= 0.66 && immersion >= 0.55 {
            return "끌림과 몰입을 함께 즐기는 취향이에요"
        }
        if playfulness >= 0.66 && pace >= 0.6 {
            return "가볍게 티키타카하며 빠르게 가까워지는 취향이에요"
        }
        if tempo <= 0.4 && playfulness <= 0.4 {
            return "다정하고 안정감 있는 관계를 선호하는 취향이에요"
        }
        return "설렘과 안정 사이에서 균형을 찾는 취향이에요"
    }

    private func summary(tempo: Double, pace: Double, playfulness: Double, immersion: Double, names: [String]) -> String {
        let basis = names.isEmpty ? "최애 캐릭터 대화" : names.joined(separator: " · ") + " 대화"
        let toneText = tempo >= 0.6 ? "설렘이 또렷한" : "편안하고 다정한"
        let paceText = pace >= 0.6 ? "가까워지는 속도가 빠른" : "천천히 신뢰를 쌓는"
        return "\(basis)에서, \(toneText) 분위기와 \(paceText) 흐름을 좋아하는 결이 보였어요. 이 취향을 바탕으로 소개팅 추천이 가능한지 살펴봤어요."
    }

    private func keywordTags(tempo: Double, pace: Double, playfulness: Double, immersion: Double) -> [String] {
        var tags: [String] = []
        tags.append(tempo >= 0.6 ? "설렘 있는 대화" : "편안한 대화")
        tags.append(pace >= 0.6 ? "빠른 친밀감" : "천천히 신뢰")
        tags.append(playfulness >= 0.6 ? "장난스러운 밀당" : "다정한 직진")
        tags.append(immersion >= 0.6 ? "몰입형 분위기" : "일상 공유")
        return tags
    }
}
