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
    var day: LoadState<NutritionDay> = .idle

    // MARK: - Init

    init(
        clock: any DateProvider = SystemDateProvider(),
        source: (any NutritionSource)? = nil
    ) {
        self.clock = clock
        self.source = source ?? MockNutritionSource(now: clock.now)
        self.selectedDate = ISODate.string(clock.now)
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
}
