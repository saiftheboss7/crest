import Foundation

@MainActor
enum DateFormatting {
    private static var cachedFormatters: [String: DateFormatter] = [:]

    static func formatter(for format: String) -> DateFormatter {
        if let cached = cachedFormatters[format] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        cachedFormatters[format] = formatter
        return formatter
    }

    static func menuBarString(date: Date, format: String, showSeconds: Bool) -> String {
        var resolvedFormat = format
        if !showSeconds {
            resolvedFormat = resolvedFormat
                .replacingOccurrences(of: ":ss", with: "")
                .replacingOccurrences(of: ":SS", with: "")
        } else if !resolvedFormat.contains("ss") && !resolvedFormat.contains("SS") {
            resolvedFormat = resolvedFormat
                .replacingOccurrences(of: "mm", with: "mm:ss")
        }
        return formatter(for: resolvedFormat).string(from: date)
    }

    static func eventTimeRange(start: Date, end: Date, isAllDay: Bool) -> String {
        if isAllDay { return "All Day" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
    }

    static func relativeDayHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
