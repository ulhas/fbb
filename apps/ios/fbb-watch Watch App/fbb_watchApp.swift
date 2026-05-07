import SwiftUI

@main
struct fbb_watch_Watch_AppApp: App {
    @State private var env = WatchAppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootViewWithRoutes()
                .environment(env)
                .task {
                    // Bootstrap the WC relay once. The sender wires
                    // itself to WorkoutStore lifecycle callbacks so
                    // session start/update/end forwards to the iPhone
                    // Live Activity automatically.
                    WatchActivityRelaySender.shared.bootstrap(store: env.store)
                }
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
        // watchOS UI is always dark — pin the colorScheme so SPM-bundled
        // asset-catalog colors resolve to their dark-luminosity variant
        // instead of falling back to the universal/light value.
        .preferredColorScheme(.dark)
    }
}
