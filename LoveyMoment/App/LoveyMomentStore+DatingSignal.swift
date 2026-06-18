import Foundation

/// Lovey Signal 분석 진행 상태.
enum DatingSignalAnalysisState: Equatable {
    case idle
    case analyzing
    case complete
    case failed
}

/// 최애 캐릭터 대화 → 관계 취향 분석 → 소개팅 추천 가능성 플로우의 상태/액션.
/// 실제 매칭/연락/결제는 다루지 않으며 후보는 모두 예시 프로필이다.
@MainActor
extension LoveyMomentStore {
    /// 분석 대상으로 고른 대화 수.
    var selectedSignalConversationCount: Int {
        signalConversationSelections.filter(\.isSelected).count
    }

    /// 분석을 시작할 수 있는 최소 조건(2개 이상 선택).
    var canAnalyzeDatingPreference: Bool {
        (2...3).contains(selectedSignalConversationCount)
    }

    /// Signal 홈에서 "취향 분석 시작"을 누르면 상태를 초기화하고 동의 화면으로 이동한다.
    func startDatingSignal() {
        resetDatingSignal()
        prepareSignalConversationSelections()
        push(.datingSignalIntro)
    }

    /// 현재 캐릭터 목록으로 대화 선택 후보를 준비한다.
    private func prepareSignalConversationSelections() {
        signalConversationSelections = characters.map { character in
            FavoriteConversationSelection(
                characterId: character.id,
                characterName: character.name,
                generatedAvatarKey: character.generatedAvatarKey,
                genreLabel: character.stats.genreLabel,
                lastSceneSummary: lastSceneSummary(for: character),
                isSelected: false
            )
        }
    }

    /// 동의 항목 토글.
    func setConsentConversationAnalysis(_ value: Bool) {
        datingSignalConsent.agreesToConversationAnalysis = value
    }

    func setConsentExampleProfilesOnly(_ value: Bool) {
        datingSignalConsent.agreesToExampleProfilesOnly = value
    }

    func setConsentNoRealMatching(_ value: Bool) {
        datingSignalConsent.agreesToNoRealMatching = value
    }

    /// 3가지 동의가 모두 끝나면 대화 선택 화면으로 진행한다.
    func agreeDatingSignalConsent() {
        guard datingSignalConsent.isComplete else { return }
        push(.datingSignalSelection)
    }

    /// 대화 선택 토글. 최대 3개까지만 선택할 수 있다.
    func toggleSignalConversationSelection(_ selection: FavoriteConversationSelection) {
        guard let index = signalConversationSelections.firstIndex(where: { $0.id == selection.id }) else { return }
        let willSelect = !signalConversationSelections[index].isSelected
        if willSelect, selectedSignalConversationCount >= 3 {
            toastMessage = "대화는 최대 3개까지 고를 수 있어요."
            return
        }
        signalConversationSelections[index].isSelected = willSelect
    }

    /// 선택한 대화로 취향 분석을 시작하고 분석 화면으로 이동한다.
    func analyzeDatingPreference() {
        guard canAnalyzeDatingPreference else { return }
        datingSignalAnalysisState = .analyzing
        datingSignalErrorMessage = nil
        relationshipPreferenceProfile = nil
        push(.datingSignalAnalysis)

        let selections = signalConversationSelections
        Task {
            // 분석 단계 연출을 위한 짧은 지연(서비스형 진행감).
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            let profile = environment.datingSignalAnalyzer.analyzePreference(from: selections)
            relationshipPreferenceProfile = profile
            datingSignalAnalysisState = .complete
            print("[DatingSignal] analysisComplete axes=\(profile.axes.count) basedOn=\(profile.basedOnCharacterNames.joined(separator: ","))")
        }
    }

    /// 분석 결과 화면으로 이동한다.
    func showDatingPreferenceProfile() {
        guard relationshipPreferenceProfile != nil else { return }
        push(.datingSignalProfile)
    }

    /// 취향 프로필 기반 예시 후보를 만들고 추천 화면으로 이동한다.
    func loadDatingMatchCandidates() {
        guard let profile = relationshipPreferenceProfile else { return }
        datingMatchCandidates = environment.datingSignalAnalyzer.recommendedCandidates(for: profile)
        print("[DatingSignal] candidatesLoaded count=\(datingMatchCandidates.count)")
        push(.datingSignalRecommendations)
    }

    /// 예시 후보 상세를 연다.
    func openCandidateDetail(_ candidate: DatingMatchCandidate) {
        selectedDatingCandidate = candidate
        push(.datingSignalCandidateDetail(candidate.id))
    }

    /// 전체 Signal 상태를 초기화한다.
    func resetDatingSignal() {
        datingSignalConsent = .empty
        signalConversationSelections = []
        relationshipPreferenceProfile = nil
        datingMatchCandidates = []
        datingSignalAnalysisState = .idle
        datingSignalErrorMessage = nil
        selectedDatingCandidate = nil
    }

    /// Signal 탭의 NavigationStack을 루트로 되돌린다.
    func popSignalToRoot() {
        signalPath = []
    }
}
