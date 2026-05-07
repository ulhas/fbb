import SwiftUI

@main
struct fbb_watch_Watch_AppApp: App {
    @State private var env = WatchAppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootViewWithRoutes()
                .environment(env)
        }
    }
}

private struct RootViewWithRoutes: View {
    @Environment(WatchAppEnvironment.self) private var env
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WatchHomeView(path: $path)
                .navigationTitle("FBB")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case .activeSession:
                        WatchWorkoutView(path: $path)
                    case .summary:
                        WatchSummaryView(path: $path)
                    }
                }
        }
        .tint(.fbbOrange)
    }
}
