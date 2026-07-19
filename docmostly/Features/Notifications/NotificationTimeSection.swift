import Foundation

nonisolated enum NotificationTimeSection: Int, CaseIterable, Identifiable, Sendable {
    case today
    case yesterday
    case thisWeek
    case older

    var id: Self { self }

    var title: String {
        switch self {
        case .today:
            "Today"
        case .yesterday:
            "Yesterday"
        case .thisWeek:
            "This Week"
        case .older:
            "Older"
        }
    }

    static func section(for date: Date?, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Self {
        guard let date else { return .older }
        let startOfToday = calendar.startOfDay(for: now)
        guard date < startOfToday else { return .today }

        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        guard date < startOfYesterday else { return .yesterday }

        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfYesterday
        return date >= startOfWeek ? .thisWeek : .older
    }
}
