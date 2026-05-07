import Foundation
import Observation
import FBBWorkoutKitNet

/// Lightweight DI container for the watch app. Holds the long-lived
/// dependencies the views and view models need. Mirrors iOS's AppEnvironment
/// so both apps construct the shared services the same way.
@Observable
@MainActor
final class WatchAppEnvironment {
    let api: APIClient
    let session: WatchSessionStore

    init(api: APIClient? = nil, session: WatchSessionStore? = nil) {
        self.api = api ?? APIClient()
        self.session = session ?? WatchSessionStore()
    }
}
