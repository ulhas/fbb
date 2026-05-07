import Foundation
import Observation
import FBBWorkoutKitCore
import FBBWorkoutKitNet

/// Watch-side Today loader.
///
/// Tries today first; if no week covers today, falls back to the most-
/// recent week and shows whichever day in that week is closest to today
/// (capped at the last day of the week). Honest about which date is on
/// screen via `displayedDate`.
@Observable
@MainActor
final class WatchHomeViewModel {
    enum LoadState: Sendable {
        case idle
        case loading
        case loaded(cells: [TrainingWeekDayCellRow], displayedDate: String, isToday: Bool)
        case empty(reason: String)
        case failed(String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    private let api: APIClient
    var state: LoadState = .idle

    init(api: APIClient) {
        self.api = api
    }

    func load(force: Bool = false) async {
        state = .loading
        do {
            let weeks = try await api.listWeeks(forceRefresh: force)
            guard !weeks.isEmpty else {
                state = .empty(reason: "No weeks available yet.")
                return
            }
            let today = ISO8601.todayString()
            let resolved = pickWeekAndDate(weeks: weeks, today: today)

            let detail = try await api.day(
                weekStartsOn: resolved.weekStartsOn,
                scheduledOn: resolved.scheduledOn,
                forceRefresh: force
            )

            guard !detail.cells.isEmpty else {
                state = .empty(reason: "No tracks scheduled for \(resolved.scheduledOn).")
                return
            }
            state = .loaded(
                cells: detail.cells,
                displayedDate: resolved.scheduledOn,
                isToday: resolved.scheduledOn == today
            )
        } catch let apiError as APIError {
            if case .notFound = apiError {
                state = .empty(reason: "No day data found.")
            } else {
                state = .failed(apiError.errorDescription ?? "Couldn't load today.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Pick which (week, date) the user should see when they open the watch:
    /// 1. The week that contains today, with today as the date.
    /// 2. Otherwise the most-recent week (highest weekStartsOn), with today
    ///    clamped into that week's range.
    private struct Resolved {
        let weekStartsOn: String
        let scheduledOn: String
    }

    private func pickWeekAndDate(weeks: [TrainingWeekSummaryRow], today: String) -> Resolved {
        if let week = weeks.first(where: { $0.weekStartsOn <= today && today <= $0.weekEndsOn }) {
            return Resolved(weekStartsOn: week.weekStartsOn, scheduledOn: today)
        }
        // No week covers today. Pick the week that's closest in time and use
        // its weekStartsOn (Monday) — Sundays in this catalog tend to be
        // lesson days with no exercises, while Mondays reliably have
        // workouts. Better fallbacks come once we fetch week detail.
        let latest = weeks.max(by: { $0.weekStartsOn < $1.weekStartsOn })!
        return Resolved(weekStartsOn: latest.weekStartsOn, scheduledOn: latest.weekStartsOn)
    }
}

/// Tiny ISO-date helper used by both the home VM and the watch session
/// store. Mirrors the iOS `ISODate` helper without depending on it.
enum ISO8601 {
    static func todayString(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    /// Pretty short form: "May 7" or "May 7 2026" if not current year.
    static func prettyDate(_ iso: String, now: Date = Date()) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .iso8601)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }

        let pretty = DateFormatter()
        pretty.calendar = Calendar(identifier: .iso8601)
        pretty.locale = Locale(identifier: "en_US_POSIX")
        pretty.timeZone = .current
        let cal = Calendar(identifier: .iso8601)
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: now)
        pretty.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return pretty.string(from: date)
    }
}
