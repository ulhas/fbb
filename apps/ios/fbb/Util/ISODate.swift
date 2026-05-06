import Foundation

/// Helpers for the API's `YYYY-MM-DD` ISO date strings. Dates flow as String
/// across the wire and through models; we parse only at the view layer.
enum ISODate {
    /// UTC ISO-8601 calendar formatter (date-only, no time-of-day).
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Calendar fixed to the user's locale + UTC, used for component extraction.
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }

    static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }

    static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Today's date as `YYYY-MM-DD` in the user's UTC calendar — matches
    /// how the API's `scheduled_on` is stored.
    static func todayString(_ now: Date = Date()) -> String {
        string(now)
    }

    static func dayOfMonth(_ iso: String) -> Int? {
        guard let date = parse(iso) else { return nil }
        return calendar.component(.day, from: date)
    }

    /// Single-letter weekday — M T W T F S S — for compact day chips.
    static func weekdayLetter(_ iso: String) -> String {
        guard let date = parse(iso) else { return "·" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEEE" // narrow style: M, T, W, T, F, S, S
        return f.string(from: date)
    }

    /// Full weekday — Monday, Tuesday — for headers and accessibility labels.
    static func weekdayName(_ iso: String) -> String {
        guard let date = parse(iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// "May 6" style short month-day for greeting subtitles.
    static func monthDay(_ iso: String) -> String {
        guard let date = parse(iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// "Apr 27 – May 3" style range, used by previous-weeks rows.
    static func rangeLabel(start: String, end: String) -> String {
        let s = monthDay(start)
        let e = monthDay(end)
        return s.isEmpty || e.isEmpty ? "\(start) – \(end)" : "\(s) – \(e)"
    }
}
