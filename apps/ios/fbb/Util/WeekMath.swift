import Foundation

enum WeekMath {
    /// Picks the summary row whose `[weekStartsOn, weekEndsOn]` range contains
    /// `today`. Falls back to the newest row if today is outside every range
    /// (e.g., user is on holiday and the latest week has already ended).
    static func currentWeek(
        among rows: [TrainingWeekSummaryRow],
        today: Date
    ) -> TrainingWeekSummaryRow? {
        guard !rows.isEmpty else { return nil }
        let todayISO = ISODate.string(today)
        if let match = rows.first(where: { todayISO >= $0.weekStartsOn && todayISO <= $0.weekEndsOn }) {
            return match
        }
        // Rows are returned newest-first by the API, but we don't trust order —
        // sort by start date descending and pick the head.
        return rows.max(by: { $0.weekStartsOn < $1.weekStartsOn })
    }

    /// Saturday-drop heuristic: surface the "new week" banner when today is
    /// Sat/Sun OR the newest week's `weekStartsOn` is within ±2 days of today.
    /// This guards both the calendar trigger and the "data just landed" trigger.
    static func shouldShowSaturdayDrop(
        rows: [TrainingWeekSummaryRow],
        today: Date,
        calendar: Calendar = .iso8601UTC
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: today)
        // ISO calendar: 1 = Sunday, 7 = Saturday in Gregorian; with .iso8601 as
        // identifier the firstWeekday is Monday but `.weekday` still returns
        // Gregorian indexing. Saturday = 7, Sunday = 1.
        let isWeekendDrop = (weekday == 7 || weekday == 1)

        guard let newest = rows.max(by: { $0.weekStartsOn < $1.weekStartsOn }),
              let dropDate = ISODate.parse(newest.weekStartsOn) else {
            return isWeekendDrop
        }
        let deltaDays = abs(calendar.dateComponents([.day], from: today, to: dropDate).day ?? 0)
        return isWeekendDrop || deltaDays <= 2
    }
}

extension Calendar {
    /// ISO-8601 calendar pinned to UTC so date math matches the API's
    /// timezone-naive `YYYY-MM-DD` strings.
    static var iso8601UTC: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }
}
