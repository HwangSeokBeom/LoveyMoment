import SwiftUI

/// Lovey Signal 탭의 루트. 최애 캐릭터 대화로 드러난 관계 취향을 분석해
/// 소개팅 추천이 가능한지 보여주는 후속 확장 기능의 진입점.
struct SignalHomeView: View {
    @EnvironmentObject private var store: LoveyMomentStore

    private let topAnchor = "signal-top"

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 0).id(topAnchor)
                        header
                        heroCard
                        howItWorksCard
                        if let profile = store.relationshipPreferenceProfile {
                            recentAnalysisCard(profile)
                        }
                        safetyCard
                    }
                    .padding(18)
                    .padding(.bottom, 120)
                }
                .refreshable { await store.refreshSignal() }
                .onChange(of: store.signalScrollToTopToken) { _, _ in
                    withAnimation { proxy.scrollTo(topAnchor, anchor: .top) }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lovey Signal")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.white)
                .onTapGesture { store.signalScrollToTopToken += 1 }
            Text("최애 캐릭터 대화로 보는 나의 관계 취향")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "관계 취향 분석")

                Text("내가 가장 많이 대화한 캐릭터들의 결을 모아, 어떤 관계를 편안해하는지 읽어드려요.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("분석한 취향을 바탕으로, 소개팅 추천이 가능한지까지 예시로 확인할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    signalStep(icon: "bubble.left.and.text.bubble.right.fill", title: "대화 고르기")
                    signalStep(icon: "waveform.path.ecg", title: "취향 분석")
                    signalStep(icon: "person.2.fill", title: "추천 예시")
                }

                PrimaryCTAButton(title: "취향 분석 시작하기", systemImage: "sparkles") {
                    store.startDatingSignal()
                }
            }
        }
    }

    private func signalStep(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(PoCTheme.primary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var howItWorksCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "이렇게 분석해요")

                infoRow(
                    number: "1",
                    title: "최애 캐릭터 대화를 고르면",
                    detail: "내가 자주 나눈 대화의 분위기와 거리감을 함께 살펴봐요."
                )
                infoRow(
                    number: "2",
                    title: "관계 취향을 4가지 결로 정리하고",
                    detail: "대화 온도·속도·표현·몰입 성향을 부드럽게 그려드려요."
                )
                infoRow(
                    number: "3",
                    title: "어울리는 추천 예시를 보여줘요",
                    detail: "실제 인물이 아닌 예시 프로필로, 추천 가능성만 확인해요."
                )
            }
        }
    }

    private func infoRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 26, height: 26)
                .background(Circle().fill(PoCTheme.primary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recentAnalysisCard(_ profile: RelationshipPreferenceProfile) -> some View {
        Button {
            store.showDatingPreferenceProfile()
        } label: {
            CardContainer {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionEyebrow(text: "최근 분석한 취향")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Text(profile.headline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if !profile.keywordTags.isEmpty {
                        // 카드 전체가 취향 상세로 가는 버튼이라, "+N"은 정보 표시만(탭하면 카드가 상세로 이동해 전체 노출).
                        CompactTagRow(tags: profile.keywordTags, maxVisible: 3)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var safetyCard: some View {
        let notice = DatingSafetyNotice.standard
        return CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label(notice.title, systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PoCTheme.secondary)
                ForEach(notice.points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 6)
                        Text(point)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// "+N" 칩을 눌렀을 때 전체 키워드를 보여주는 sheet의 입력값.
struct TagSheetPayload: Identifiable {
    let id = UUID()
    let title: String
    let tags: [String]
}

/// 추천 카드 내부 전용 단일 행 태그.
/// 각 칩은 텍스트 폭에 맞는 intrinsic width(고정폭 아님)라, "리드" 같은 짧은 태그는 짧게 보인다.
/// maxVisible 초과분은 "+N" 버튼으로 접고, 누르면 onOverflowTap으로 전체 키워드를 띄운다.
/// 한 줄 HStack + trailing Spacer라 칩들이 카드 폭을 균등 분할하지 않는다.
struct CompactTagRow: View {
    let tags: [String]
    var maxVisible: Int = 2
    /// "+N" 탭 시 호출. nil이면 "+N"은 정보 표시용 칩으로만 그려진다(상위 컨테이너가 탭 처리).
    var onOverflowTap: (() -> Void)? = nil

    private var visibleTags: [String] {
        guard tags.count > maxVisible else { return tags }
        return Array(tags.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, tags.count - visibleTags.count)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visibleTags, id: \.self) { tag in
                CompactTagChip(text: tag, color: PoCTheme.primary)
            }
            if overflowCount > 0 {
                if let onOverflowTap {
                    Button(action: onOverflowTap) {
                        CompactTagChip(text: "+\(overflowCount)", color: PoCTheme.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    CompactTagChip(text: "+\(overflowCount)", color: PoCTheme.secondary)
                }
            }
            // 남는 폭을 빈 공간으로 밀어내, 칩들이 늘어나지 않고 왼쪽에 붙도록 한다.
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

/// 텍스트 폭에 맞는 캡슐 칩. 고정폭/균등분배 없이 intrinsic width만 차지한다.
struct CompactTagChip: View {
    let text: String
    var color: Color = PoCTheme.primary

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            // 가로는 콘텐츠 폭에 고정 → 짧은 태그는 짧게, 균등 셀처럼 늘어나지 않는다.
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
                    .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
            )
    }
}

/// "+N" 탭 시 전체 키워드를 보여주는 sheet 콘텐츠.
struct TagCloudSheet: View {
    let payload: TagSheetPayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PoCTheme.background.ignoresSafeArea()
                ScrollView {
                    PreferenceKeywordCloud(tags: payload.tags)
                        .padding(20)
                }
            }
            .navigationTitle(payload.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 관계 취향 키워드처럼 "전부 보여야 하는" 태그를 여러 줄로 자연스럽게 wrap하는 클라우드.
/// 추천 카드와 달리 "+N"으로 접지 않고, 좁으면 다음 줄로 내려간다. 칩은 잘리지 않는다.
struct PreferenceKeywordCloud: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                CompactTagChip(text: tag, color: PoCTheme.primary)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 태그들을 가로로 흐르게 배치하는 간단한 래퍼.
struct FlexibleTagRow: View {
    let tags: [String]
    /// 0이면 제한 없음. 양수면 그 개수까지만 보여주고 나머지는 "+N"으로 묶는다.
    var limit: Int = 0

    private var visibleTags: [String] {
        guard limit > 0, tags.count > limit else { return tags }
        return Array(tags.prefix(limit))
    }

    private var overflow: Int {
        guard limit > 0 else { return 0 }
        return max(0, tags.count - limit)
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(visibleTags, id: \.self) { tag in
                TagPill(text: tag, color: PoCTheme.primary)
                    .fixedSize()
            }
            if overflow > 0 {
                TagPill(text: "+\(overflow)", color: PoCTheme.secondary)
                    .fixedSize()
            }
        }
        // 부모 너비를 가득 받아 카드 밖으로 칩이 삐져나가지 않도록 한다.
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 가용 너비에 맞춰 줄바꿈하는 단순 Flow 레이아웃.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
