import SwiftUI

@main
struct fbbApp: App {
    @State private var api = APIClient()
    @State private var userStore: UserStore

    init() {
        let api = APIClient()
        _api = State(wrappedValue: api)
        _userStore = State(wrappedValue: UserStore(api: api))
    }

    var body: some Scene {
        WindowGroup {
            RootView(api: api, userStore: userStore)
                .environment(userStore)
                .task { await userStore.bootstrap() }
        }
    }
}
