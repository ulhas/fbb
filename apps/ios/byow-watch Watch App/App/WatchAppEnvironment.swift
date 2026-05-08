import Foundation
import Observation
import BYOWWorkoutKitCore
import BYOWWorkoutKitNet

/// Lightweight DI container for the watch app. Holds the long-lived
/// dependencies the views and view models need. Mirrors iOS's AppEnvironment
/// so both apps construct the shared services the same way.
@Observable
@MainActor
final class WatchAppEnvironment {
    let api: APIClient
    let store: WorkoutStore

    init(api: APIClient? = nil, store: WorkoutStore? = nil) {
        self.api = api ?? APIClient()
        self.store = store ?? WorkoutStore()
    }
}
