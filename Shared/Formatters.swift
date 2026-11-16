import Foundation

enum Format {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    /// 7.5 -> "7h 30m"
    static func hours(_ value: Double) -> String {
        let minutes = Int((max(0, value) * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    static func clock(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return timeFormatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    static func duration(_ minutes: Double) -> String {
        let total = Int(max(0, minutes).rounded())
        if total >= 60 {
            return "\(total / 60) 小时 \(total % 60) 分"
        }
        return "\(total) 分钟"
    }
}
