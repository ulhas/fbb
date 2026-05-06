import Foundation
import Observation

@Observable
@MainActor
final class NutritionViewModel {

    // Local mirror of the Stats LoadState. When we extract a shared one to
    // Util/, this can collapse to a typealias.
    enum LoadState<V>: @unchecked Sendable {
        case idle
        case loading
        case loaded(V)
        case failed(APIError)

        var value: V? {
            if case .loaded(let v) = self { return v }
            return nil
        }
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    // MARK: - Dependencies

    private let clock: any DateProvider
    private var source: any NutritionSource

    // MARK: - State

    /// Currently-selected ISO date (the date the hero + meals reflect).
    var selectedDate: String

    /// Monday of the week shown in the picker. Stepped by `goToPreviousWeek`
    /// / `goToNextWeek`. Always anchored to the start of an ISO week so the
    /// picker shows a clean Mon-Sun window.
    var viewedWeekStart: String

    var day: LoadState<NutritionDay> = .idle

    // MARK: - Init

    init(
        clock: any DateProvider = SystemDateProvider(),
        source: (any NutritionSource)? = nil
    ) {
        self.clock = clock
        self.source = source ?? MockNutritionSource(now: clock.now)
        let today = ISODate.string(clock.now)
        self.selectedDate = today
        self.viewedWeekStart = Self.mondayOf(today)
    }

    // MARK: - Lifecycle

    func onAppear() async {
        if case .loaded = day { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    // MARK: - Actions

    func selectDate(_ iso: String) {
        guard selectedDate != iso else { return }
        selectedDate = iso
        Task { await load(forceRefresh: false) }
    }

    func goToPreviousWeek() {
        guard let prev = Self.shiftedWeek(viewedWeekStart, byWeeks: -1) else { return }
        viewedWeekStart = prev
        // Anchor selection inside the new window so the picker reads naturally.
        selectedDate = prev
        Task { await load(forceRefresh: false) }
    }

    func goToNextWeek() {
        guard canGoNextWeek,
              let next = Self.shiftedWeek(viewedWeekStart, byWeeks: 1) else { return }
        viewedWeekStart = next
        // Snap selection to today if we're returning to the current week,
        // otherwise the Monday of the new week.
        let today = todayISO
        let candidates = weekDates(from: next)
        selectedDate = candidates.contains(today) ? today : next
        Task { await load(forceRefresh: false) }
    }

    // MARK: - Loaders

    private func load(forceRefresh: Bool) async {
        day = .loading
        do {
            let value = try await source.loadDay(date: selectedDate, forceRefresh: forceRefresh)
            day = .loaded(value)
        } catch let error as APIError {
            day = .failed(error)
        } catch {
            day = .failed(.unknown(error.localizedDescription))
        }
    }

    // MARK: - Derived: picker

    var todayISO: String { ISODate.string(clock.now) }

    var canGoPreviousWeek: Bool { true }

    /// Forward navigation stops at the current calendar week — there's no
    /// nutrition to log in the future.
    var canGoNextWeek: Bool {
        viewedWeekStart < Self.mondayOf(todayISO)
    }

    var weekRangeLabel: String? {
        let dates = weekDates(from: viewedWeekStart)
        guard let start = dates.first, let end = dates.last else { return nil }
        return ISODate.rangeLabel(start: start, end: end)
    }

    /// 7 calendar dates Mon-Sun starting from `viewedWeekStart`. Indicator
    /// is derived from the in-memory `dateStrip` when it overlaps the
    /// viewed window; otherwise dates fall back to past/today/future
    /// heuristics so the picker always renders something useful.
    var weekItems: [WeekDayPickerItem] {
        let today = todayISO
        let dates = weekDates(from: viewedWeekStart)
        let stripByDate: [String: DateStripDay.LogState] = {
            guard let strip = day.value?.dateStrip else { return [:] }
            var map: [String: DateStripDay.LogState] = [:]
            for entry in strip { map[entry.date] = entry.logState }
            return map
        }()

        return dates.map { iso in
            let logState = stripByDate[iso]
            let indicator = Self.indicator(for: iso, today: today, logState: logState)
            return WeekDayPickerItem(date: iso, indicator: indicator)
        }
    }

    private func weekDates(from monday: String) -> [String] {
        guard let start = ISODate.parse(monday) else { return [] }
        let cal = Calendar.iso8601UTC
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: start).map(ISODate.string)
        }
    }

    // MARK: - Static helpers

    /// Snaps an ISO date to the Monday of its ISO-8601 week.
    private static func mondayOf(_ iso: String) -> String {
        guard let date = ISODate.parse(iso) else { return iso }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let monday = cal.date(from: comps) ?? date
        return ISODate.string(monday)
    }

    /// Shifts a Monday-anchored week start by N weeks.
    private static func shiftedWeek(_ monday: String, byWeeks: Int) -> String? {
        guard let date = ISODate.parse(monday),
              let shifted = Calendar.iso8601UTC.date(byAdding: .day, value: byWeeks * 7, to: date) else {
            return nil
        }
        return ISODate.string(shifted)
    }

    /// Translates per-day log state (or absence of it) into a picker
    /// indicator. Future dates with no log get no dot; today defaults to
    /// `.partial` even before the first food is logged so it stands out.
    private static func indicator(
        for iso: String,
        today: String,
        logState: DateStripDay.LogState?
    ) -> WeekDayPickerItem.Indicator? {
        switch logState {
        case .complete:  return .complete
        case .partial:   return .partial
        case .untouched: return iso > today ? nil : .planned
        case .future:    return nil
        case .none:
            // No state in the strip — use date math.
            if iso > today { return nil }
            if iso == today { return .partial }
            return .planned
        }
    }
}
