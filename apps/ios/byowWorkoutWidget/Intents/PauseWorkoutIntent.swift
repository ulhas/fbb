import ActivityKit
import AppIntents
import Foundation

struct PauseWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Workout"
    static var description = IntentDescription("Pause or resume the running workout.")

    init() {}

    func perform() async throws -> some IntentResult {
        // LiveActivityIntent.perform() runs in the app's process. The
        // app-side LiveActivityBridge is registered as an observer for
        // this notification name (see LiveActivityBridge.swift).
        NotificationCenter.default.post(
            name: Notification.Name("byow.liveActivity.togglePause"),
            object: nil
        )
        return .result()
    }
}
