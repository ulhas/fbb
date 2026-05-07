import Foundation
import Observation
import FBBWorkoutKitCore
import FBBWorkoutKitNet

/// Watch-side Today loader.
///
/// - Resolves the available date range from the latest training week
///   (the watch lets the user step forwards/backwards within it).
/// - Filters cells to the user's followed tracks (falls back to all
///   cells if the user has zero follows, matching iOS behaviour so the
///   screen never goes blank).
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

    /// Sorted list of dates the user can step through (the latest week's
    /// 7 days). Empty until the first load completes.
    private(set) var availableDates: [String] = []

    /// Currently-selected date. Drives which day detail is fetched.
    private(set) var selectedDate: String?

    /// Set of track codes the user follows. nil while loading; empty set
    /// means the user follows nothing (we fall back to all cells).
    private var followedTrackCodes: Set<String>?

    /// Cache of last successful day fetch so date stepping is snappy.
    private var dayCache: [String: [TrainingWeekDayCellRow]] = [:]

    init(api: APIClient) {
        self.api = api
    }

    var canGoPrevious: Bool {
        guard let selected = selectedDate,
              let idx = availableDates.firstIndex(of: selected) else { return false }
        return idx > 0
    }

    var canGoNext: Bool {
        guard let selected = selectedDate,
              let idx = availableDates.firstIndex(of: selected) else { return false }
        return idx < availableDates.count - 1
    }

    func goToPrevious() {
        guard canGoPrevious,
              let selected = selectedDate,
              let idx = availableDates.firstIndex(of: selected) else { return }
        selectedDate = availableDates[idx - 1]
        Task { await loadSelectedDate() }
    }

    func goToNext() {
        guard canGoNext,
              let selected = selectedDate,
              let idx = availableDates.firstIndex(of: selected) else { return }
        selectedDate = availableDates[idx + 1]
        Task { await loadSelectedDate() }
    }

    func load(force: Bool = false) async {
        state = .loading
        do {
            // Pull the user's follow set in parallel with the week list.
            async let mePromise: Me? = try? await api.me(forceRefresh: force)
            let weeks = try await api.listWeeks(forceRefresh: force)

            guard !weeks.isEmpty else {
                state = .empty(reason: "No weeks available yet.")
                return
            }

            let me = await mePromise
            self.followedTrackCodes = Set(me?.followedTrackCodes ?? [])

            // Build the available-dates list from the latest week (Mon–Sun).
            let latest = weeks.max(by: { $0.weekStartsOn < $1.weekStartsOn })!
            availableDates = makeDates(from: latest.weekStartsOn, to: latest.weekEndsOn)

            // Pick the initial selection: today if it's in range, else the
            // latest week's Monday (most reliably a workout day).
            if selectedDate == nil {
                let today = ISO8601.todayString()
                selectedDate = availableDates.contains(today) ? today : latest.weekStartsOn
            }

            await loadSelectedDate(force: force)
        } catch let apiError as APIError {
            state = .failed(apiError.errorDescription ?? "Couldn't load.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadSelectedDate(force: Bool = false) async {
        guard let selected = selectedDate else { return }
        guard let week = weekFor(date: selected) else {
            state = .empty(reason: "No data for \(ISO8601.prettyDate(selected)).")
            return
        }

        state = .loading

        do {
            let cells: [TrainingWeekDayCellRow]
            if !force, let cached = dayCache[selected] {
                cells = cached
            } else {
                let detail = try await api.day(
                    weekStartsOn: week,
                    scheduledOn: selected,
                    forceRefresh: force
                )
                cells = detail.cells
                dayCache[selected] = cells
            }

            // Filter to followed tracks; fall back to all cells if the user
            // follows none — better to show something than a blank screen.
            let filtered: [TrainingWeekDayCellRow]
            if let follows = followedTrackCodes, !follows.isEmpty {
                let scoped = cells.filter { follows.contains($0.track.trackCode) }
                filtered = scoped.isEmpty ? cells : scoped
            } else {
                filtered = cells
            }

            if filtered.isEmpty {
                state = .empty(reason: "No tracks scheduled for \(ISO8601.prettyDate(selected)).")
            } else {
                let today = ISO8601.todayString()
                state = .loaded(cells: filtered, displayedDate: selected, isToday: selected == today)
            }
        } catch let apiError as APIError {
            if case .notFound = apiError {
                state = .empty(reason: "No data for \(ISO8601.prettyDate(selected)).")
            } else {
                state = .failed(apiError.errorDescription ?? "Couldn't load that day.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Build [Mon, Tue, ..., Sun] for the given week range. Strings stay
    /// lexicographically sortable (ISO yyyy-MM-dd).
    private func makeDates(from start: String, to end: String) -> [String] {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .iso8601)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = "yyyy-MM-dd"
        guard let startDate = parser.date(from: start),
              let endDate = parser.date(from: end) else { return [start] }

        var dates: [String] = []
        var cursor = startDate
        let cal = Calendar(identifier: .iso8601)
        while cursor <= endDate {
            dates.append(parser.string(from: cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    /// Find the weekStartsOn for a given date — for now just returns the
    /// week we already loaded, since date stepping stays inside one week.
    private func weekFor(date: String) -> String? {
        guard let first = availableDates.first else { return nil }
        return first
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

    /// Weekday shortcut: "Mon" / "Tue" / etc.
    static func weekdayShort(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .iso8601)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return "" }
        let pretty = DateFormatter()
        pretty.calendar = Calendar(identifier: .iso8601)
        pretty.locale = Locale(identifier: "en_US_POSIX")
        pretty.timeZone = .current
        pretty.dateFormat = "EEE"
        return pretty.string(from: date)
    }
}
