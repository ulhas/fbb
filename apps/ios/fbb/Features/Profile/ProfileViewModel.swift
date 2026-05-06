import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {

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
    private var source: any ProfileSource

    // MARK: - State

    var profile: LoadState<ProfileData> = .idle

    // MARK: - Init

    init(
        api: APIClient,
        entitlements: EntitlementsStore,
        clock: any DateProvider = SystemDateProvider(),
        source: (any ProfileSource)? = nil
    ) {
        self.api = api
        self.entitlements = entitlements
        self.clock = clock
        self.source = source ?? MockProfileSource(now: clock.now)
    }

    // MARK: - Lifecycle

    func onAppear() async {
        if case .loaded = profile { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    // MARK: - In-place mutations (mock-only writes; Phase 2 hits the backend)

    func setNotification(_ keyPath: WritableKeyPath<NotificationPrefs, Bool>, to value: Bool) {
        guard case .loaded(var current) = profile else { return }
        var prefs = current.notifications
        prefs[keyPath: keyPath] = value
        current = withUpdated(current, notifications: prefs)
        profile = .loaded(current)
    }

    func setPrivacy(_ keyPath: WritableKeyPath<PrivacyPrefs, Bool>, to value: Bool) {
        guard case .loaded(var current) = profile else { return }
        var prefs = current.privacy
        prefs[keyPath: keyPath] = value
        current = withUpdated(current, privacy: prefs)
        profile = .loaded(current)
    }

    func setBiometric(_ enabled: Bool) {
        guard case .loaded(var current) = profile else { return }
        var account = current.account
        account.hasBiometricLogin = enabled
        current = withUpdated(current, account: account)
        profile = .loaded(current)
    }

    func setAIPersonality(_ p: CoachAssignment.AIPersonality) {
        guard case .loaded(var current) = profile,
              var coach = current.coach else { return }
        coach.aiPersonality = p
        current = withUpdated(current, coach: coach)
        profile = .loaded(current)
    }

    func setBody(_ body: BodyProfile) {
        guard case .loaded(var current) = profile else { return }
        current = withUpdated(current, body: body)
        profile = .loaded(current)
    }

    /// Mock logout — clears API cache. Phase 2 will also call Supabase signOut
    /// and deselect tracks if the new account differs.
    func logout() {
        Task { await api.clearCache() }
    }

    // MARK: - Private

    private func load(forceRefresh: Bool) async {
        profile = .loading
        do {
            let value = try await source.loadProfile(forceRefresh: forceRefresh)
            profile = .loaded(value)
        } catch let error as APIError {
            profile = .failed(error)
        } catch {
            profile = .failed(.unknown(error.localizedDescription))
        }
    }

    private func withUpdated(
        _ data: ProfileData,
        notifications: NotificationPrefs? = nil,
        privacy: PrivacyPrefs? = nil,
        account: AccountInfo? = nil,
        coach: CoachAssignment? = nil,
        body: BodyProfile? = nil
    ) -> ProfileData {
        ProfileData(
            user: data.user,
            subscription: data.subscription,
            body: body ?? data.body,
            account: account ?? data.account,
            coach: coach ?? data.coach,
            notifications: notifications ?? data.notifications,
            privacy: privacy ?? data.privacy,
            appInfo: data.appInfo
        )
    }
}
