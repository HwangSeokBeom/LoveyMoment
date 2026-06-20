import SwiftUI

/// 당근 스타일 활동 알림 센터. 캐릭터 메시지/Moment/Signal/설정 활동을 한곳에 모아
/// 날짜 그룹·읽음 상태·필터로 보여주고, 각 항목을 탭하면 해당 화면으로 이동한다.
struct NotificationCenterView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: NotificationCenterFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                PoCTheme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                        filterBar
                        if filteredItems.isEmpty {
                            emptyState
                        } else {
                            ForEach(NotificationDateGroup.allCases, id: \.self) { group in
                                let items = groupedItems[group] ?? []
                                if !items.isEmpty {
                                    groupSection(group, items: items)
                                }
                            }
                        }
                        settingsSection
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("알림")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("모두 읽음") { store.markAllNotificationsRead() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .disabled(store.unreadNotificationCount == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                store.refreshNotificationAuthorizationStatus()
            }
        }
        .tint(.white)
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NotificationCenterFilter.allCases) { option in
                    let isSelected = filter == option
                    Button {
                        filter = option
                    } label: {
                        HStack(spacing: 5) {
                            Text(option.title)
                            if option == .all, store.unreadNotificationCount > 0 {
                                Text("\(store.unreadNotificationCount)")
                                    .font(.caption2.weight(.heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(PoCTheme.primary))
                                    .foregroundStyle(.black.opacity(0.82))
                            }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.82) : .white.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isSelected ? PoCTheme.primary : Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Groups

    private func groupSection(_ group: NotificationDateGroup, items: [AppNotificationItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white.opacity(0.85))
            VStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        store.openNotification(item)
                        dismiss()
                    } label: {
                        itemRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func itemRow(_ item: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: item.iconName)
                    .font(.headline)
                    .foregroundStyle(iconColor(item.category))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(iconColor(item.category).opacity(0.16)))
                if !item.isRead {
                    Circle()
                        .fill(PoCTheme.primary)
                        .frame(width: 9, height: 9)
                        .offset(x: 2, y: -1)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.relativeText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.isRead ? PoCTheme.card : PoCTheme.cardStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PoCTheme.stroke, lineWidth: 1)
                )
        )
    }

    private func iconColor(_ category: AppNotificationItem.Category) -> Color {
        switch category {
        case .character: return PoCTheme.primary
        case .moment: return PoCTheme.secondary
        case .signal: return PoCTheme.primary
        case .system: return .white.opacity(0.7)
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(text: "알림 설정")

                switch store.notificationAuthorizationStatus {
                case .notDetermined:
                    PrimaryCTAButton(title: "알림 켜기", systemImage: "bell.fill") {
                        store.requestNotificationAuthorization()
                    }
                case .denied:
                    PrimaryCTAButton(title: "설정에서 알림 허용", systemImage: "gearshape.fill") {
                        store.openSystemNotificationSettings()
                    }
                default:
                    EmptyView()
                }

                ForEach(store.characters) { character in
                    HStack(spacing: 12) {
                        CharacterPortraitView(character: character, size: 40, style: .mini)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(character.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(character.stats.genreLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.isNotificationEnabled(for: character) },
                            set: { store.setNotificationEnabled($0, for: character) }
                        ))
                        .labelsHidden()
                        .tint(PoCTheme.primary)
                    }
                }

                SecondaryActionButton(title: "캐릭터 메시지 미리 받아보기", systemImage: "envelope.badge") {
                    store.scheduleTestCharacterNotification()
                }

                if let status = store.testNotificationStatusText {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
            Text("아직 받은 알림이 없어요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data

    private var filteredItems: [AppNotificationItem] {
        store.activityNotificationItems.filter { filter.matches($0) }
    }

    private var groupedItems: [NotificationDateGroup: [AppNotificationItem]] {
        Dictionary(grouping: filteredItems) { $0.group() }
    }
}
