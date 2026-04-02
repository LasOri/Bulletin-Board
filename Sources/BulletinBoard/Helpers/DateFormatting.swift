import LINKER

enum DateFormatting {

    static let secondsPerMinute: Double = 60
    static let secondsPerHour: Double = 3600
    static let secondsPerDay: Double = 86400
    static let secondsPerWeek: Double = 604800
    static let secondsPerMonth: Double = 2592000

    static func relativeDate(from timestamp: Double) -> String {
        let seconds = currentTimestamp() - timestamp
        if seconds < secondsPerMinute {
            return "just now"
        } else if seconds < secondsPerHour {
            let minutes = Int(seconds / secondsPerMinute)
            return "\(minutes)m ago"
        } else if seconds < secondsPerDay {
            let hours = Int(seconds / secondsPerHour)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / secondsPerDay)
            return "\(days)d ago"
        }
    }
}
