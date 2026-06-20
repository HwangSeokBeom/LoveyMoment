import SwiftUI

/// 홈 검색창을 탭하면 열리는 전체 검색 화면.
/// 추천 검색어·인기 태그·최근 검색어를 보여주고, 입력 중에는 캐릭터를 필터링한 결과를 보여준다.
struct HomeSearchView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    @State private var query = ""
    @AppStorage("home.recentSearches") private var recentSearchesRaw = ""

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                Divider().overlay(PoCTheme.stroke)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            recommendedSection
                            popularTagsSection
                            recentSection
                        } else {
                            resultsSection
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.55))
                TextField("캐릭터, 세계관, 태그 검색", text: $query)
                    .focused($isFieldFocused)
                    .foregroundStyle(.white)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { commit(query) }
                if !query.isEmpty {
                    Button {
                        query = ""
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )

            Button("취소") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Suggestion sections

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("추천 검색어")
            FlowLayout(spacing: 8) {
                ForEach(store.recommendedSearchTerms, id: \.self) { term in
                    chip(term, filled: true) { commit(term) }
                }
            }
        }
    }

    @ViewBuilder
    private var popularTagsSection: some View {
        if !store.popularSearchTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("인기 태그")
                FlowLayout(spacing: 8) {
                    ForEach(store.popularSearchTags, id: \.self) { tag in
                        chip("#\(tag)", filled: false) { commit(tag) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("최근 검색어")
                    Spacer()
                    Button("전체 삭제") { recentSearchesRaw = "" }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                ForEach(recentSearches, id: \.self) { term in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Button {
                            query = term
                            commit(term)
                        } label: {
                            Text(term)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            removeRecent(term)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        let results = store.searchedCharacters(for: query)
        if results.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.4))
                Text("‘\(query)’에 맞는 캐릭터가 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                Text("다른 키워드나 추천 검색어로 찾아보세요.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("검색 결과 \(results.count)")
                ForEach(results) { character in
                    Button {
                        commit(query)
                        dismiss()
                        store.openDetail(for: character)
                    } label: {
                        resultRow(character)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resultRow(_ character: CharacterProfile) -> some View {
        HStack(spacing: 14) {
            CharacterPortraitView(character: character, size: 56, style: .mini)
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(character.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                TagPill(text: character.stats.genreLabel, color: PoCTheme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
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

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
    }

    private func chip(_ text: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? Color.black.opacity(0.82) : .white.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(filled ? PoCTheme.primary : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private var recentSearches: [String] {
        recentSearchesRaw
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func commit(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        var list = recentSearches.filter { $0 != trimmed }
        list.insert(trimmed, at: 0)
        recentSearchesRaw = list.prefix(5).joined(separator: "\n")
        hideKeyboard()
    }

    private func removeRecent(_ term: String) {
        recentSearchesRaw = recentSearches.filter { $0 != term }.joined(separator: "\n")
    }
}
