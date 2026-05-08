import ActivityKit
import AppIntents
import Foundation

struct LogSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var description = IntentDescription("Mark the next prescribed set complete.")

    init() {}

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: Notification.Name("byow.liveActivity.logSet"),
            object: nil
        )
        return .result()
    }
}
