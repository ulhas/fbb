import Foundation
import Observation

/// Server-backed source of truth for "who am I" and "which tracks do I follow".
///
/// Replaces the Phase-1 UserDefaults `EntitlementsStore`. Optimistically
/// updates the local follow set on toggle, then reconciles against the API.
/// Persists the last known follow set to UserDefaults so a cold launch
/// renders something coherent before `bootstrap()` resolves.
///
/// The legacy property names (`selectedTrackCodes`, `toggle`, `has`) are
/// preserved as-is so existing call sites in Stats/Profile keep working
/// without a sweep — this store *is* the entitlements store, just with a
/// different name and a network behind it.
@Observable
@MainActor
final class UserStore {
    enum LoadState<V>: @unchecked Sendable {
        case idle
        case loading
        case loaded(V)
        case failed(APIError)

        var value: V? {
            if case .loaded(let v) = self { return v }
            return nil
        }
    }

    private static let cacheKey = "fbb.userStore.followedTrackCodes.v1"

    private let api: APIClient

    /// Canonical list of followed track codes. Reads are synchronous; writes
    /// happen via `toggle(_:)` / `follow(_:)` / `unfollow(_:)` which take the
    /// server roundtrip and roll back on failure.
    var selectedTrackCodes: [String] {
        didSet {
            UserDefaults.standard.set(selectedTrackCodes, forKey: Self.cacheKey)
        }
    }

    var me: LoadState<Me> = .idle
    var catalog: LoadState<[TrackCatalogRow]> = .idle

    init(api: APIClient) {
        self.api = api
        self.selectedTrackCodes =
            UserDefaults.standard.stringArray(forKey: Self.cacheKey) ?? []
    }

    // MARK: - Lifecycle

    /// Reconcile the local follow set against the server. Idempotent — safe
    /// to call from every `.task` modifier on screens that depend on it.
    func bootstrap(force: Bool = false) async {
        if !force, case .loaded = me { return }
        me = .loading
        do {
            let value = try await api.me(forceRefresh: force)
            me = .loaded(value)
            selectedTrackCodes = value.followedTrackCodes
        } catch let error as APIError {
            me = .failed(error)
        } catch {
            me = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Loads (or refreshes) the picker catalog. Cheap — eight rows for the
    /// foreseeable future. Always force-refreshes after a follow/unfollow so
    /// `isFollowed` flags stay accurate.
    func loadCatalog(force: Bool = false) async {
        if !force, case .loaded = catalog { return }
        catalog = .loading
        do {
            let value = try await api.tracksCatalog(forceRefresh: force)
            catalog = .loaded(value)
        } catch let error as APIError {
            catalog = .failed(error)
        } catch {
            catalog = .failed(.unknown(error.localizedDescription))
        }
    }

    // MARK: - Mutations (optimistic)

    func toggle(_ code: String) {
        if selectedTrackCodes.contains(code) {
            unfollow(code)
        } else {
            follow(code)
        }
    }

    func follow(_ code: String) {
        guard !selectedTrackCodes.contains(code) else { return }
        selectedTrackCodes.append(code)
        Task { @MainActor in
            do {
                try await api.followTrack(code)
                await refreshCatalogQuietly()
            } catch {
                // Rollback the optimistic add.
                selectedTrackCodes.removeAll { $0 == code }
            }
        }
    }

    func unfollow(_ code: String) {
        guard selectedTrackCodes.contains(code) else { return }
        let originalIndex = selectedTrackCodes.firstIndex(of: code)
        selectedTrackCodes.removeAll { $0 == code }
        Task { @MainActor in
            do {
                try await api.unfollowTrack(code)
                await refreshCatalogQuietly()
            } catch {
                // Rollback the optimistic remove (best-effort position restore).
                if let originalIndex, !selectedTrackCodes.contains(code) {
                    let clamped = min(originalIndex, selectedTrackCodes.count)
                    selectedTrackCodes.insert(code, at: clamped)
                }
            }
        }
    }

    func has(_ code: String) -> Bool {
        selectedTrackCodes.contains(code)
    }

    // MARK: - Internals

    private func refreshCatalogQuietly() async {
        do {
            let value = try await api.tracksCatalog(forceRefresh: true)
            catalog = .loaded(value)
        } catch {
            // Catalog is non-critical UI; silent failure keeps the picker
            // stale rather than throwing the whole screen into an error.
        }
    }
}
