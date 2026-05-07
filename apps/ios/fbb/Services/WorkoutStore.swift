import Foundation
import Observation

/// Owns the active workout session. Lifted out of `WorkoutDetailView`
/// so the session survives tab switches — when the user pops over to
/// Stats or Nutrition while training, the timer keeps running and the
/// `tabViewBottomAccessory` mini-player stays in view.
///
/// The store holds *one* session at a time. v1 doesn't allow multiple
/// concurrent workouts; the iOS UI doesn't let users start a second one
/// while the first is in flight.
@Observable
@MainActor
final class WorkoutStore {
    private(set) var activeSession: WorkoutSession?
    private var ticker: SessionTicker?

    /// Set when the user starts a workout. Holds the session for the
    /// duration of running + summary. Cleared once the user saves or
    /// abandons.
    func attach(_ session: WorkoutSession) {
        activeSession = session
    }

    /// Begin the running phase: starts the engine, kicks off the 1Hz
    /// ticker, snapshots locally for crash recovery.
    func start() {
        guard let session = activeSession else { return }
        session.startWorkout()
        let ticker = SessionTicker(session: session)
        ticker.start()
        self.ticker = ticker
        SessionPersistence.snapshot(session)
    }

    /// End the running phase (transitions to summary). Stops the ticker
    /// but keeps the session in the store — `clear()` happens on save.
    func end() {
        guard let session = activeSession else { return }
        session.endWorkout()
        ticker?.stop()
        ticker = nil
        SessionPersistence.snapshot(session)
    }

    func togglePause() {
        guard let session = activeSession else { return }
        if session.isPaused {
            session.resumeWorkout()
        } else {
            session.pauseWorkout()
        }
    }

    /// Drop the active session entirely (after a successful sync or
    /// abandonment). The accessory disappears, ticker is fully cleaned
    /// up.
    func clear() {
        ticker?.stop()
        ticker = nil
        activeSession = nil
    }

    /// Route the user can navigate to in order to surface the active
    /// workout's detail view. Used by the bottom-accessory tap handler.
    var activeRoute: NavRoute? {
        guard let session = activeSession else { return nil }
        return .workout(
            trackCode: session.trackCode,
            week: session.weekStartsOn,
            day: session.scheduledOn
        )
    }

    /// True only when the workout is in flight (not pre-start, not
    /// summary). The accessory shows when this is true.
    var hasRunningSession: Bool {
        activeSession?.phase == .running
    }
}
