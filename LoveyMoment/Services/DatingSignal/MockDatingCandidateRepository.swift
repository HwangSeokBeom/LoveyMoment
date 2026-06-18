import Foundation

/// 소개팅 추천 "예시" 후보 저장소. 실제 인물이 아닌 고정 예시 프로필을 제공하고,
/// 취향 프로필과의 결을 결정적으로 계산해 가까운 순으로 정렬한다.
enum MockDatingCandidateRepository {
    /// 후보별 성향 벡터(취향 프로필과 같은 4축).
    private struct Seed {
        let displayName: String
        let ageLabel: String
        let oneLine: String
        let about: String
        let gradientKey: String
        let initials: String
        let vibeTags: [String]
        let tempo: Double
        let pace: Double
        let playfulness: Double
        let immersion: Double
    }

    private static let seeds: [Seed] = [
        Seed(
            displayName: "여름밤",
            ageLabel: "20대 후반",
            oneLine: "조용한 카페에서 오래 대화하는 걸 좋아해요",
            about: "퇴근 후 산책과 플레이리스트 공유가 취미예요. 처음엔 천천히, 편하게 알아가는 사이를 좋아해요.",
            gradientKey: "dusk",
            initials: "YB",
            vibeTags: ["편안한 대화", "천천히 신뢰", "다정한 직진"],
            tempo: 0.3, pace: 0.35, playfulness: 0.25, immersion: 0.35
        ),
        Seed(
            displayName: "노을",
            ageLabel: "20대 중반",
            oneLine: "장난도 잘 치고 금방 친해지는 편이에요",
            about: "새로운 사람과 티키타카하는 걸 좋아하고, 갑자기 떠나는 짧은 여행을 즐겨요.",
            gradientKey: "coral",
            initials: "NO",
            vibeTags: ["장난스러운 밀당", "빠른 친밀감", "활발함"],
            tempo: 0.6, pace: 0.85, playfulness: 0.85, immersion: 0.35
        ),
        Seed(
            displayName: "심야",
            ageLabel: "30대 초반",
            oneLine: "깊은 이야기를 천천히 나누는 시간을 아껴요",
            about: "밤에 영화·소설 이야기로 길게 빠지는 걸 좋아하고, 분위기에 몰입하는 관계에 끌려요.",
            gradientKey: "midnight",
            initials: "SY",
            vibeTags: ["몰입형 분위기", "천천히 신뢰", "진중함"],
            tempo: 0.7, pace: 0.25, playfulness: 0.3, immersion: 0.9
        ),
        Seed(
            displayName: "설원",
            ageLabel: "20대 후반",
            oneLine: "끌리는 사람에겐 또렷하게 표현하는 편이에요",
            about: "처음엔 차분하지만 마음이 가면 솔직하게 다가가요. 설레는 긴장감이 있는 대화를 좋아해요.",
            gradientKey: "violet",
            initials: "SW",
            vibeTags: ["설렘 있는 대화", "또렷한 끌림", "리드"],
            tempo: 0.85, pace: 0.45, playfulness: 0.35, immersion: 0.55
        ),
        Seed(
            displayName: "햇살",
            ageLabel: "20대 중반",
            oneLine: "곁에 있으면 편안하다는 말을 자주 들어요",
            about: "소소한 일상을 나누는 걸 좋아하고, 다정하게 안정감을 주는 관계를 선호해요.",
            gradientKey: "honey",
            initials: "HS",
            vibeTags: ["편안한 대화", "안정감", "다정한 직진"],
            tempo: 0.35, pace: 0.5, playfulness: 0.25, immersion: 0.3
        )
    ]

    static func candidates(for profile: RelationshipPreferenceProfile) -> [DatingMatchCandidate] {
        let target = axisValues(profile)

        let ranked = seeds
            .map { seed -> (Seed, Double) in
                let distance = abs(seed.tempo - target.tempo)
                    + abs(seed.pace - target.pace)
                    + abs(seed.playfulness - target.playfulness)
                    + abs(seed.immersion - target.immersion)
                return (seed, distance)
            }
            .sorted { $0.1 < $1.1 }

        return ranked.prefix(4).map { seed, distance in
            DatingMatchCandidate(
                displayName: seed.displayName,
                ageLabel: seed.ageLabel,
                oneLine: seed.oneLine,
                about: seed.about,
                gradientKey: seed.gradientKey,
                initials: seed.initials,
                vibeTags: seed.vibeTags,
                reasons: reasons(seed: seed, target: target),
                affinityLabel: affinityLabel(distance: distance)
            )
        }
    }

    private static func axisValues(_ profile: RelationshipPreferenceProfile) -> (tempo: Double, pace: Double, playfulness: Double, immersion: Double) {
        func value(_ title: String) -> Double {
            profile.axes.first { $0.title == title }?.value ?? 0.5
        }
        return (
            tempo: value("대화 온도"),
            pace: value("관계 속도"),
            playfulness: value("표현 방식"),
            immersion: value("몰입 성향")
        )
    }

    private static func reasons(seed: Seed, target: (tempo: Double, pace: Double, playfulness: Double, immersion: Double)) -> [DatingMatchReason] {
        var reasons: [DatingMatchReason] = []

        if abs(seed.tempo - target.tempo) <= 0.25 {
            reasons.append(DatingMatchReason(
                title: "대화 온도가 잘 맞아요",
                detail: target.tempo >= 0.6
                    ? "설레는 긴장감이 있는 대화를 비슷하게 즐겨요."
                    : "편안하고 잔잔한 대화 결이 닮아 있어요."
            ))
        }
        if abs(seed.pace - target.pace) <= 0.25 {
            reasons.append(DatingMatchReason(
                title: "가까워지는 속도가 비슷해요",
                detail: target.pace >= 0.6
                    ? "마음이 통하면 빠르게 가까워지는 흐름을 좋아해요."
                    : "시간을 들여 천천히 신뢰를 쌓는 걸 좋아해요."
            ))
        }
        if abs(seed.playfulness - target.playfulness) <= 0.25 {
            reasons.append(DatingMatchReason(
                title: "표현 방식이 닮았어요",
                detail: target.playfulness >= 0.6
                    ? "장난스러운 티키타카를 함께 즐길 수 있어요."
                    : "돌려 말하기보다 다정하게 직진하는 결이 비슷해요."
            ))
        }
        if abs(seed.immersion - target.immersion) <= 0.25 {
            reasons.append(DatingMatchReason(
                title: "몰입 성향이 통해요",
                detail: target.immersion >= 0.6
                    ? "둘만의 분위기에 깊이 빠지는 시간을 좋아해요."
                    : "특별한 설정보다 일상을 나누는 걸 편안해해요."
            ))
        }

        if reasons.isEmpty {
            reasons.append(DatingMatchReason(
                title: "새로운 결을 더해줄 수 있어요",
                detail: "내 취향과 조금 다른 매력이 있어, 새로운 분위기를 경험해볼 수 있어요."
            ))
        }
        return reasons
    }

    private static func affinityLabel(distance: Double) -> String {
        switch distance {
        case ..<0.5: return "결이 아주 잘 맞아요"
        case ..<1.0: return "결이 잘 맞는 편이에요"
        case ..<1.6: return "닮은 점이 있어요"
        default: return "새로운 결을 더해줘요"
        }
    }
}
