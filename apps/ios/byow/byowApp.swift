import SwiftUI

@main
struct byowApp: App {
    @State private var api = APIClient()
    @State private var userStore: UserStore
    @State private var workoutStore: WorkoutStore
    @State private var liveActivity = WorkoutLiveActivityController()

    init() {
        let api = APIClient()
        let store = WorkoutStore()
        _api = State(wrappedValue: api)
        _userStore = State(wrappedValue: UserStore(api: api))
        _workoutStore = State(wrappedValue: store)

        // Wire the App-Intent bridge once. iOS launches Live-Activity
        // intent handlers into this app process, so they need a
        // process-wide hook to reach the running store.
        let bridge = LiveActivityBridge()
        bridge.store = store
        LiveActivityBridge.shared = bridge
    }

    var body: some Scene {
        WindowGroup {
            RootView(api: api, userStore: userStore, workoutStore: workoutStore)
                .environment(userStore)
                .environment(workoutStore)
                .environment(liveActivity)
                .task { await userStore.bootstrap() }
                .task { await bootstrapLiveActivity() }
        }
    }

    private func bootstrapLiveActivity() async {
        // Hooks fire from WorkoutStore lifecycle. Set them once;
        // captures `liveActivity` weakly to avoid a retain cycle.
        workoutStore.onSessionStarted = { [weak liveActivity] session in
            liveActivity?.start(session: session)
        }
        workoutStore.onSessionEnded = { [weak liveActivity] session in
            Task { await liveActivity?.endIfMatches(session: session) }
        }
        workoutStore.onSessionCleared = { [weak liveActivity] session in
            Task { await liveActivity?.endIfMatches(session: session) }
        }

        LiveActivityRelayReceiver.shared.bootstrap(
            controller: liveActivity,
            bridge: LiveActivityBridge.shared
        )
        await liveActivity.bootstrap(activeSessionId: workoutStore.activeSession?.sessionId)
    }
}
