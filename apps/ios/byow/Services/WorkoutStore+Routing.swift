import Foundation

// iOS-only routing helper. The shared `WorkoutStore` lives in the package
// and doesn't know about `NavRoute`, so we surface "what route does the
// active session map to?" as an iOS-side extension. The mini-player's
// tap handler reads this to deep-link back into the running workout.

extension WorkoutStore {
    var activeRoute: NavRoute? {
        guard let session = activeSession else { return nil }
        return .workout(
            trackCode: session.trackCode,
            week: session.weekStartsOn,
            day: session.scheduledOn
        )
    }
}
