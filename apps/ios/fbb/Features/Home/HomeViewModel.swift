import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
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

    private let api: APIClient
    private let userStore: UserStore
    private let clock: any DateProvider

    // MARK: - Server-fed state

    var weekList: LoadState<[TrainingWeekSummaryRow]> = .idle
    var viewedWeek: LoadState<TrainingWeekDetailRow> = .idle
    var dayDetail: LoadState<TrainingWeekDayDetailRow> = .idle

    // MARK: - User selection

    /// The week being viewed in the picker. Defaults to the calendar week that
    /// contains today; nudged by `goToPreviousWeek` / `goToNextWeek`.
    var viewedWeekStartsOn: String?

    /// ISO date inside `viewedWeek`. Tapping a day pill updates this and
    /// reloads the per-day detail.
    var selectedDate: String?

    init(
        api: APIClient,
        userStore: UserStore,
        clock: any DateProvider = SystemDateProvider()
    ) {
        self.api = api
        self.userStore = userStore
        self.clock = clock
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await loadWeekList()
        defaultToCurrentWeekIfNeeded()
        await loadViewedWeek()
        ensureSelectedDate()
        await loadSelectedDay()
    }

    func refresh() async {
        await loadWeekList(force: true)
        await loadViewedWeek(force: true)
        await loadSelectedDay(force: true)
    }

    // MARK: - User actions

    func selectDate(_ iso: String) {
        guard selectedDate != iso else { return }
        selectedDate = iso
        Task { await loadSelectedDay() }
    }

    func goToPreviousWeek() {
        guard let prev = previousWeekStartsOn else { return }
        switchWeek(to: prev)
    }

    func goToNextWeek() {
        guard let next = nextWeekStartsOn else { return }
        switchWeek(to: next)
    }

    // MARK: - Loaders

    private func loadWeekList(force: Bool = false) async {
        weekList = .loading
        do {
            let value = try await api.listWeeks(forceRefresh: force)
            weekList = .loaded(value)
        } catch let error as APIError {
            weekList = .failed(error)
        } catch {
            weekList = .failed(.unknown(error.localizedDescription))
        }
    }

    private func loadViewedWeek(force: Bool = false) async {
        guard let week = viewedWeekStartsOn else {
            viewedWeek = .idle
            return
        }
        viewedWeek = .loading
        do {
            let value = try await api.week(week, forceRefresh: force)
            viewedWeek = .loaded(value)
        } catch let error as APIError {
            viewedWeek = .failed(error)
        } catch {
            viewedWeek = .failed(.unknown(error.localizedDescription))
        }
    }

    private func loadSelectedDay(force: Bool = false) async {
        guard case .loaded(let week) = viewedWeek,
              let date = selectedDate else {
            dayDetail = .idle
            return
        }
        dayDetail = .loading
        do {
            let value = try await api.day(
                weekStartsOn: week.weekStartsOn,
                scheduledOn: date,
                forceRefresh: force
            )
            dayDetail = .loaded(value)
        } catch let error as APIError {
            dayDetail = .failed(error)
        } catch {
            dayDetail = .failed(.unknown(error.localizedDescription))
        }
    }

    private func switchWeek(to weekStartsOn: String) {
        viewedWeekStartsOn = weekStartsOn
        // Reset selected date — it'll be re-anchored once the new week loads.
        selectedDate = nil
        dayDetail = .idle
        Task {
            await loadViewedWeek()
            ensureSelectedDate()
            await loadSelectedDay()
        }
    }

    private func defaultToCurrentWeekIfNeeded() {
        guard viewedWeekStartsOn == nil,
              case .loaded(let rows) = weekList,
              let pick = WeekMath.currentWeek(among: rows, today: clock.now) else {
            return
        }
        viewedWeekStartsOn = pick.weekStartsOn
    }

    /// Pick a default selected date inside the viewed week:
    /// - Today, if today falls inside the week
    /// - Otherwise the first day of the week
    private func ensureSelectedDate() {
        guard selectedDate == nil else { return }
        let today = ISODate.string(clock.now)
        let days = weekDays
        if days.contains(where: { $0.scheduledOn == today }) {
            selectedDate = today
        } else {
            selectedDate = days.first?.scheduledOn
        }
    }

    // MARK: - Derived: week navigation

    /// Sorted list of week start dates from the catalog (newest first).
    private var orderedWeekStarts: [String] {
        guard case .loaded(let rows) = weekList else { return [] }
        return rows.map(\.weekStartsOn).sorted(by: >)
    }

    var previousWeekStartsOn: String? {
        guard let current = viewedWeekStartsOn else { return nil }
        let starts = orderedWeekStarts
        guard let idx = starts.firstIndex(of: current) else { return nil }
        let prev = idx + 1 // older = larger index since sorted desc
        return prev < starts.count ? starts[prev] : nil
    }

    var nextWeekStartsOn: String? {
        guard let current = viewedWeekStartsOn else { return nil }
        let starts = orderedWeekStarts
        guard let idx = starts.firstIndex(of: current) else { return nil }
        let next = idx - 1
        return next >= 0 ? starts[next] : nil
    }

    var canGoPreviousWeek: Bool { previousWeekStartsOn != nil }
    var canGoNextWeek: Bool { nextWeekStartsOn != nil }

    // MARK: - Derived: rendering

    /// 7 days for the picker — taken from any one track in the viewed week.
    /// Tracks share calendar dates within a week, so any of them works.
    var weekDays: [TrainingWeekDayMetaRow] {
        guard case .loaded(let week) = viewedWeek else { return [] }
        let base = week.tracks.first?.days ?? []
        return base.sorted { $0.scheduledOn < $1.scheduledOn }
    }

    /// Picker-ready projection of `weekDays` — workout/active-recovery days
    /// get a dot whose tint comes from past/today/future, rest days stay
    /// dotless. The picker view itself doesn't know about training kinds.
    var weekItems: [WeekDayPickerItem] {
        let today = todayISO
        return weekDays.map { day in
            let indicator: WeekDayPickerItem.Indicator?
            switch day.kind {
            case .workout, .activeRecovery:
                if day.scheduledOn < today      { indicator = .complete }
                else if day.scheduledOn == today { indicator = .partial }
                else                             { indicator = .planned }
            case .rest, .mobility, .lesson:
                indicator = nil
            }
            return WeekDayPickerItem(date: day.scheduledOn, indicator: indicator)
        }
    }

    /// The full day cells for the selected date, scoped to followed tracks
    /// and ordered by family / cadence so the stack is stable across loads.
    var followedDayCells: [TrainingWeekDayCellRow] {
        guard case .loaded(let detail) = dayDetail else { return [] }
        let followed = Set(userStore.selectedTrackCodes)
        let filtered = detail.cells.filter { followed.contains($0.track.trackCode) }
        // If the user follows tracks but none align with this week's data,
        // fall back to all cells so the screen never goes blank.
        let pool = filtered.isEmpty ? detail.cells : filtered
        return pool.sorted(by: trackOrdering)
    }

    private func trackOrdering(_ a: TrainingWeekDayCellRow, _ b: TrainingWeekDayCellRow) -> Bool {
        let familyRank: [TrackFamily: Int] = [
            .pumpLift: 0,
            .pumpCondition: 1,
            .perform: 2,
            .minimalist: 3,
            .hybridRunning: 4,
            .workshop: 5,
            .onramp: 6,
        ]
        let af = familyRank[a.track.family] ?? 99
        let bf = familyRank[b.track.family] ?? 99
        if af != bf { return af < bf }
        let cadenceRank: [TrackCadence?: Int] = [
            .x5: 0, .x4: 1, .x3: 2, .custom: 3, nil: 4,
        ]
        let ac = cadenceRank[a.track.cadence] ?? 9
        let bc = cadenceRank[b.track.cadence] ?? 9
        if ac != bc { return ac < bc }
        return a.track.trackCode < b.track.trackCode
    }

    /// Hint for the nutrition card's tone. Workout if any followed track is
    /// training today; rest if every followed track is resting.
    var workoutDayKindHint: DayKind? {
        let cells = followedDayCells
        guard !cells.isEmpty else { return nil }
        if cells.contains(where: { $0.day.kind == .workout }) { return .workout }
        if cells.contains(where: { $0.day.kind == .activeRecovery }) { return .activeRecovery }
        if cells.allSatisfy({ $0.day.kind == .rest }) { return .rest }
        return cells.first?.day.kind
    }

    // MARK: - Derived: header context

    var todayISO: String { ISODate.string(clock.now) }

    /// Day-of-week label for the selected date — "Today" if selected == today,
    /// else the weekday name. Replaces the prior date-laden header.
    var headerTitle: String {
        guard let iso = selectedDate else { return "Today" }
        if iso == todayISO { return "Today" }
        return ISODate.weekdayName(iso)
    }

    /// "Mesocycle 2 · Week 5" if available, else `nil`. Pulls from any
    /// followed track's microcycle hint (they share within a calendar week).
    var microcycleLabel: String? {
        guard case .loaded(let week) = viewedWeek,
              let track = week.tracks.first else { return nil }
        let micro = track.microcycle
        var parts: [String] = []
        if let mesoPos = micro.mesocyclePositionHint {
            parts.append("Mesocycle \(mesoPos)")
        }
        if let weekPos = micro.weekPosition {
            parts.append("Week \(weekPos)")
        }
        if parts.isEmpty {
            parts.append(micro.kind.displayLabel)
        }
        return parts.joined(separator: " · ")
    }

    var weekRangeLabel: String? {
        guard case .loaded(let week) = viewedWeek else { return nil }
        return ISODate.rangeLabel(start: week.weekStartsOn, end: week.weekEndsOn)
    }

    var showBridgeBadge: Bool {
        guard case .loaded(let week) = viewedWeek else { return false }
        return week.tracks.contains(where: { $0.microcycle.kind == .bridgeWeek })
    }
}

enum NavRoute: Hashable {
    case week(String)
    case workout(trackCode: String, week: String, day: String)
    case profile
}
