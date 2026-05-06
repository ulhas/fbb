import Foundation
import Observation

@Observable
@MainActor
final class StatsViewModel {

    // Local LoadState mirror (HomeViewModel nests the same enum). When we
    // extract a shared one to Util/, this can collapse to a typealias.
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

    private let entitlements: EntitlementsStore
    private let clock: any DateProvider

    // The mock builder is parameterized by which hero variant to show, so the
    // VM owns that index and bumps it on every refresh — that's how the
    // pull-to-refresh "rotate the read" effect works without persistence.
    private var heroRotation: Int = 0

    // Phase 1: source is hand-injected (default = mock). Phase 2 swap to live.
    private var source: any StatsSource

    // MARK: - State

    var overview: LoadState<StatsOverview> = .idle

    // MARK: - Init

    init(
        entitlements: EntitlementsStore,
        clock: any DateProvider = SystemDateProvider(),
        source: (any StatsSource)? = nil
    ) {
        self.entitlements = entitlements
        self.clock = clock
        self.source = source ?? MockStatsSource(
            enrolledTrackCodes: entitlements.selectedTrackCodes,
            now: clock.now,
            heroIndex: 0
        )
    }

    // MARK: - Lifecycle

    func onAppear() async {
        if case .loaded = overview { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        heroRotation += 1
        rebuildSourceIfMock()
        await load(forceRefresh: true)
    }

    func refreshHero() async {
        // Same behavior as refresh for now — the mock rebuild is what swaps
        // the hero copy. Kept as a separate entry point so the hero card can
        // own its own loading affordance if we want it later.
        await refresh()
    }

    // MARK: - Loaders

    private func load(forceRefresh: Bool) async {
        overview = .loading
        do {
            let value = try await source.loadOverview(forceRefresh: forceRefresh)
            overview = .loaded(value)
        } catch let error as APIError {
            overview = .failed(error)
        } catch {
            overview = .failed(.unknown(error.localizedDescription))
        }
    }

    private func rebuildSourceIfMock() {
        if let _ = source as? MockStatsSource {
            source = MockStatsSource(
                enrolledTrackCodes: entitlements.selectedTrackCodes,
                now: clock.now,
                heroIndex: heroRotation
            )
        }
    }
}
