import Foundation

/// 선택한 최애 캐릭터 대화에서 관계 취향 프로필을 도출하고,
/// 그 취향에 맞는 소개팅 추천 "예시" 후보를 제공하는 분석기 인터페이스.
protocol DatingSignalAnalyzing {
    /// 선택한 대화들에서 관계 취향 프로필을 만든다.
    func analyzePreference(from selections: [FavoriteConversationSelection]) -> RelationshipPreferenceProfile

    /// 취향 프로필에 어울리는 예시 추천 후보를 반환한다.
    func recommendedCandidates(for profile: RelationshipPreferenceProfile) -> [DatingMatchCandidate]
}
