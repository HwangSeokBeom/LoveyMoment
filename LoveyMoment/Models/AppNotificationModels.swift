import SwiftUI

/// 당근 스타일 알림 센터에 쌓이는 활동 항목.
struct AppNotificationItem: Identifiable, Hashable {
    enum Category: String, CaseIterable, Hashable {
        case character
        case moment
        case signal
        case system
    }

    enum Destination: Hashable {
        case chat(UUID)
        case momentTab
        case signalTab
        case notificationSettings
        case healthSettings
    }

    let id: String
    let category: Category
    let title: String
    let body: String
    let date: Date
    var isRead: Bool
    let iconName: String
    let characterId: UUID?
    let destination: Destination?

    /// 날짜 그룹(오늘/어제/이전) 분류 키.
    func group(reference: Date = Date(), calendar: Calendar = .current) -> NotificationDateGroup {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        return .earlier
    }

    var relativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum NotificationDateGroup: String, CaseIterable {
    case today
    case yesterday
    case earlier

    var title: String {
        switch self {
        case .today: return "오늘"
        case .yesterday: return "어제"
        case .earlier: return "이전"
        }
    }
}

/// 알림 센터 상단 필터.
enum NotificationCenterFilter: String, CaseIterable, Identifiable {
    case all
    case character
    case moment
    case signal
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "전체"
        case .character: return "캐릭터"
        case .moment: return "Moment"
        case .signal: return "시그널"
        case .system: return "설정"
        }
    }

    func matches(_ item: AppNotificationItem) -> Bool {
        switch self {
        case .all: return true
        case .character: return item.category == .character
        case .moment: return item.category == .moment
        case .signal: return item.category == .signal
        case .system: return item.category == .system
        }
    }
}
