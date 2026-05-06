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
    private let entitlements: EntitlementsStore
    private let clock: any DateProvider

    // MARK: - Server-fed state

    var weekList: LoadState<[TrainingWeekSummaryRow]> = .idle
    var currentWeek: LoadState<TrainingWeekDetailRow> = .idle
    var dayDetail: LoadState<TrainingWeekDayDetailRow> = .idle

    // MARK: - User selection

    var selectedTrackCode: String?
    var selectedDate: String?           // ISO YYYY-MM-DD

    init(
        api: APIClient,
        entitlements: EntitlementsStore,
        clock: any DateProvider = SystemDateProvider()
    ) {
        self.api = api
        self.entitlements = entitlements
        self.clock = clock
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await loadWeekList()
        await loadCurrentWeek()
        ensureSelectedDate()
        await loadSelectedDay()
    }

    func refresh() async {
        await loadWeekList(force: true)
        await loadCurrentWeek(force: true)
        await loadSelectedDay(force: true)
    }

    // MARK: - User actions

    func selectTrack(_ code: String) {
        guard selectedTrackCode != code else { return }
        selectedTrackCode = code
        Task { await loadSelectedDay() }
    }

    func selectDate(_ iso: String) {
        guard selectedDate != iso else { return }
        selectedDate = iso
        Task { await loadSelectedDay() }
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

    private func loadCurrentWeek(force: Bool = false) async {
        guard case .loaded(let rows) = weekList,
              let pick = WeekMath.currentWeek(among: rows, today: clock.now) else {
            currentWeek = .idle
            return
        }
        currentWeek = .loading
        do {
            let value = try await api.week(pick.weekStartsOn, forceRefresh: force)
            currentWeek = .loaded(value)
            if selectedTrackCode == nil {
                selectedTrackCode = availableTracks.first?.trackCode
            }
        } catch let error as APIError {
            currentWeek = .failed(error)
        } catch {
            currentWeek = .failed(.unknown(error.localizedDescription))
        }
    }

    private func loadSelectedDay(force: Bool = false) async {
        guard case .loaded(let detail) = currentWeek,
              let day = selectedDate else {
            dayDetail = .idle
            return
        }
        dayDetail = .loading
        do {
            let value = try await api.day(
                weekStartsOn: detail.weekStartsOn,
                scheduledOn: day,
                forceRefresh: force
            )
            dayDetail = .loaded(value)
        } catch let error as APIError {
            dayDetail = .failed(error)
        } catch {
            dayDetail = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Auto-pick today if it's in the focused track's microcycle, else the
    /// first day of the microcycle. Idempotent on re-entry.
    private func ensureSelectedDate() {
        guard selectedDate == nil else { return }
        let today = ISODate.string(clock.now)
        let days = microcycleDays
        if days.contains(where: { $0.scheduledOn == today }) {
            selectedDate = today
        } else {
            selectedDate = days.first?.scheduledOn
        }
    }

    // MARK: - Derived

    var availableTracks: [TrainingWeekTrackIndexRow] {
        guard case .loaded(let week) = currentWeek else { return [] }
        let owned = Set(entitlements.selectedTrackCodes)
        let filtered = week.tracks.filter { owned.contains($0.trackCode) }
        // If the user has entitlements but none align with this week, fall back
        // to all tracks so the home screen never goes blank.
        return filtered.isEmpty ? week.tracks : filtered
    }

    var focusedTrack: TrainingWeekTrackIndexRow? {
        guard !availableTracks.isEmpty else { return nil }
        return availableTracks.first(where: { $0.trackCode == selectedTrackCode })
            ?? availableTracks.first
    }

    /// Day strip — the source of truth for the day switcher. Render whatever
    /// the focused track says, sorted by `scheduledOn`. No Mon..Sun hardcoding.
    var microcycleDays: [TrainingWeekDayMetaRow] {
        focusedTrack?.days.sorted { $0.scheduledOn < $1.scheduledOn } ?? []
    }

    var focusedDay: ParsedDay? {
        guard case .loaded(let detail) = dayDetail,
              let trackCode = focusedTrack?.trackCode else { return nil }
        return detail.cells.first(where: { $0.track.trackCode == trackCode })?.day
    }

    var showBridgeBadge: Bool {
        focusedTrack?.microcycle.kind == .bridgeWeek
    }

    var showSaturdayDrop: Bool {
        guard case .loaded(let rows) = weekList else { return false }
        return WeekMath.shouldShowSaturdayDrop(rows: rows, today: clock.now)
    }

    var todayISO: String { ISODate.string(clock.now) }
}

enum NavRoute: Hashable {
    case week(String)
    case day(week: String, day: String)
    case profile
}
