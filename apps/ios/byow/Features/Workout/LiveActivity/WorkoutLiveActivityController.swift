import ActivityKit
import Foundation
import Observation

/// Owns the lifecycle of the workout `Activity<WorkoutActivityAttributes>`.
/// Two entry-point families:
///
/// * **Local**: `start(session:)` / `endIfMatches(session:)` — invoked
///   by `WorkoutStore` callbacks for an iPhone-started workout. The
///   controller observes the session via `withObservationTracking` and
///   pushes throttled updates as state changes.
///
/// * **Relay**: `startFromRelay(_:)` / `updateFromRelay(_:)` /
///   `endFromRelay(...)` — invoked by the WC receiver for a
///   watch-started workout. No local session to observe; the watch
///   pushes deltas at its own cadence and we forward them on.
@MainActor
@Observable
final class WorkoutLiveActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?
    private(set) var sessionOriginIsWatch: Bool = false
    private var observationTask: Task<Void, Never>?
    private var lastSnapshot: WorkoutActivityAttributes.ContentState?
    private var lastPushedAt: Date = .distantPast
    /// Floor between consecutive `activity.update(_:)` calls. ActivityKit
    /// throttles aggressive updaters; the equality check below normally
    /// keeps us well under, this is a belt-and-braces ceiling.
    private let minUpdateInterval: TimeInterval = 1.5

    init() {}

    // MARK: - Local (iPhone-started)

    func start(session: WorkoutSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }
        guard let started = session.startedAt else { return }

        let attributes = WorkoutActivityAttributes(
            workoutTitle: session.day.displayName,
            trackDisplayName: session.trackDisplayName ?? session.trackCode,
            sessionId: session.sessionId,
            startedAt: started
        )
        let initial = Self.makeState(from: session)

        do {
            activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initial, staleDate: nil),
                pushType: nil
            )
            sessionOriginIsWatch = false
            LiveActivityBridge.shared?.sessionOriginIsWatch = false
            lastSnapshot = initial
            lastPushedAt = Date()
            startObserving(session)
        } catch {
            // Common failures: user disabled in Settings, concurrent
            // activity ceiling reached. No-op is correct.
        }
    }

    func endIfMatches(session: WorkoutSession) async {
        guard let activity, activity.attributes.sessionId == session.sessionId else { return }
        observationTask?.cancel()
        observationTask = nil
        let final = Self.makeState(from: session)
        await activity.end(.init(state: final, staleDate: nil), dismissalPolicy: .default)
        self.activity = nil
        self.lastSnapshot = nil
    }

    /// On launch: end any orphan activities not matching the active store.
    /// Covers the case where the app was force-quit mid-session and a
    /// stale activity is still on the lock screen.
    func bootstrap(activeSessionId: UUID?) async {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            if activity.attributes.sessionId != activeSessionId {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                self.activity = activity
            }
        }
    }

    // MARK: - Relay (watch-started)

    func startFromRelay(_ payload: WatchActivityRelay.StartPayload) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // If a different activity is already running, end it first.
        if let existing = activity, existing.attributes.sessionId != payload.sessionId {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            self.activity = nil
        }
        guard activity == nil else { return }

        let attributes = WorkoutActivityAttributes(
            workoutTitle: payload.workoutTitle,
            trackDisplayName: payload.trackDisplayName,
            sessionId: payload.sessionId,
            startedAt: payload.startedAt
        )
        let initial = state(from: payload.initialState)

        do {
            activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initial, staleDate: nil),
                pushType: nil
            )
            sessionOriginIsWatch = true
            LiveActivityBridge.shared?.sessionOriginIsWatch = true
            lastSnapshot = initial
            lastPushedAt = Date()
        } catch {
            // see start(session:)
        }
    }

    func updateFromRelay(_ payload: WatchActivityRelay.UpdatePayload) async {
        guard let activity, activity.attributes.sessionId == payload.sessionId else { return }
        let next = state(from: payload)
        await pushIfChanged(next)
    }

    /// Fast-path update for pause/resume — overrides only `pausedAt` on
    /// the most recent snapshot and pushes. The watch's next observation
    /// tick will follow with a full update; this exists so the visible
    /// pause-freeze is instantaneous.
    func applyPausedAt(_ pausedAt: Date?, sessionId: UUID) async {
        guard let activity, activity.attributes.sessionId == sessionId else { return }
        guard var snap = lastSnapshot else { return }
        snap.pausedAt = pausedAt
        await pushIfChanged(snap)
    }

    func endFromRelay(sessionId: UUID, final: WatchActivityRelay.UpdatePayload?) async {
        guard let activity, activity.attributes.sessionId == sessionId else { return }
        let finalState = final.map { state(from: $0) } ?? (lastSnapshot ?? state(from: WatchActivityRelay.UpdatePayload(
            sessionId: sessionId,
            timerStart: activity.attributes.startedAt,
            pausedAt: nil,
            currentExerciseName: "",
            setProgressLabel: "",
            groupModeLabel: nil,
            restEndsAt: nil,
            restPlannedSeconds: nil,
            setsCompleted: 0,
            setsTotal: 0
        )))
        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .default)
        self.activity = nil
        self.lastSnapshot = nil
    }

    // MARK: - Observation (local path)

    private func startObserving(_ session: WorkoutSession) {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // Read all observed properties used by makeState — this
                // registers them with `withObservationTracking` so the
                // `onChange` re-fires the next iteration when any of
                // them mutate.
                let next = withObservationTracking {
                    Self.makeState(from: session)
                } onChange: {
                    // Schedule a re-loop on the main actor on the next
                    // hop. We don't do anything synchronously — the loop
                    // body below proceeds and waits on a tiny tick.
                }
                await self.pushIfChanged(next)

                // Auto-end on phase exit.
                if case .summary = session.phase { await self.endIfMatches(session: session); return }
                if case .abandoned = session.phase { await self.endIfMatches(session: session); return }

                // Yield briefly so the onChange handler has a chance to
                // notify before we spin again. Without this we'd hot-loop.
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func pushIfChanged(_ next: WorkoutActivityAttributes.ContentState) async {
        guard let activity else { return }
        if next == lastSnapshot {
            return
        }
        let now = Date()
        if now.timeIntervalSince(lastPushedAt) < minUpdateInterval {
            // Don't drop — schedule a deferred push by sleeping. Keeps
            // the *most recent* state in the activity without burning
            // budget.
            let wait = minUpdateInterval - now.timeIntervalSince(lastPushedAt)
            try? await Task.sleep(for: .milliseconds(Int(wait * 1000)))
        }
        await activity.update(.init(state: next, staleDate: nil))
        lastSnapshot = next
        lastPushedAt = Date()
    }

    // MARK: - Mapping

    static func makeState(from session: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let started = session.startedAt ?? Date()
        let timerStart = started.addingTimeInterval(session.pausedAccumulatedSeconds)
        let restEndsAt: Date? = session.restAfter.map {
            $0.startedAt.addingTimeInterval(TimeInterval($0.plannedSeconds))
        }
        return WorkoutActivityAttributes.ContentState(
            timerStart: timerStart,
            pausedAt: session.pauseStartedAt,
            currentExerciseName: CursorDescriptors.currentExerciseName(cursor: session.cursor, in: session.day),
            setProgressLabel: CursorDescriptors.setProgressLabel(cursor: session.cursor, in: session.day),
            groupModeLabel: CursorDescriptors.groupModeLabel(activeBlock: session.activeBlock),
            restEndsAt: restEndsAt,
            restPlannedSeconds: session.restAfter?.plannedSeconds,
            setsCompleted: CursorDescriptors.setsCompleted(setLog: session.setLog),
            setsTotal: CursorDescriptors.totalSets(in: session.day)
        )
    }

    private func state(from p: WatchActivityRelay.UpdatePayload) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            timerStart: p.timerStart,
            pausedAt: p.pausedAt,
            currentExerciseName: p.currentExerciseName,
            setProgressLabel: p.setProgressLabel,
            groupModeLabel: p.groupModeLabel,
            restEndsAt: p.restEndsAt,
            restPlannedSeconds: p.restPlannedSeconds,
            setsCompleted: p.setsCompleted,
            setsTotal: p.setsTotal
        )
    }
}
