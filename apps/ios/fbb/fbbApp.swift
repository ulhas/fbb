import SwiftUI

@main
struct fbbApp: App {
    @State private var api = APIClient()
    @State private var userStore: UserStore
    @State private var workoutStore: WorkoutStore

    init() {
        let api = APIClient()
        _api = State(wrappedValue: api)
        _userStore = State(wrappedValue: UserStore(api: api))
        _workoutStore = State(wrappedValue: WorkoutStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView(api: api, userStore: userStore, workoutStore: workoutStore)
                .environment(userStore)
                .environment(workoutStore)
                .task { await userStore.bootstrap() }
        }
    }
}
