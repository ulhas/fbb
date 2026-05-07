import Foundation
import Observation
import WatchConnectivity

/// Watch-side sender for `WatchActivityRelay` payloads. Forwards session
/// lifecycle and content updates to the iPhone so the iOS Live Activity
/// can stay in sync. Also receives `intentDispatch` callbacks from the
/// iPhone (Lock-Screen button taps) and applies them to the watch's
/// `WorkoutStore`.
@MainActor
final class WatchActivityRelaySender: NSObject, WCSessionDelegate {
    static let shared = WatchActivityRelaySender()

    private let wc: WCSession = .default
    private var observationTask: Task<Void, Never>?
    private var lastPayload: WatchActivityRelay.UpdatePayload?
    private var lastSentAt: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 1.5

    /// Set by the watch app entry point so dispatched intents from
    /// iPhone (e.g. "Pause" button on Lock Screen) can mutate the
    /// running session.
    weak var store: WorkoutStore?

    func bootstrap(store: WorkoutStore) {
        guard WCSession.isSupported() else { return }
        self.store = store
        wc.delegate = self
        wc.activate()

        // Mirror the iOS side's reactive observation so the iPhone
        // activity gets fresh state without the watch having to call
        // sendUpdate manually at each mutation site.
        store.onSessionStarted = { [weak self] session in
            self?.sendStart(session: session)
            self?.startObserving(session)
        }
        store.onSessionPauseToggled = { [weak self] session in
            self?.send(.pause(sessionId: session.sessionId, pausedAt: session.pauseStartedAt))
        }
        store.onSessionEnded = { [weak self] session in
            self?.sendEnd(session: session)
        }
        store.onSessionCleared = { [weak self] session in
            self?.observationTask?.cancel()
            self?.observationTask = nil
            self?.lastPayload = nil
            self?.send(.abandon(sessionId: session.sessionId))
        }
    }

    // MARK: - Outgoing

    private func sendStart(session: WorkoutSession) {
        let payload = WatchActivityRelayBuilder.makeStart(from: session)
        send(.start(payload))
        lastPayload = payload.initialState
        lastSentAt = Date()
    }

    private func sendEnd(session: WorkoutSession) {
        observationTask?.cancel()
        observationTask = nil
        let final = WatchActivityRelayBuilder.makeUpdate(from: session)
        send(.end(WatchActivityRelay.EndPayload(sessionId: session.sessionId, finalState: final)))
        lastPayload = nil
    }

    private func send(_ relay: WatchActivityRelay) {
        guard let data = try? JSONEncoder().encode(relay) else { return }
        let dict: [String: Any] = ["payload": data]
        if wc.isReachable {
            wc.sendMessage(dict, replyHandler: nil) { _ in
                // Best effort — fall back to user-info on transport
                // failure so the activity still updates next time the
                // iPhone is reachable.
                self.wc.transferUserInfo(dict)
            }
        } else {
            wc.transferUserInfo(dict)
        }
    }

    // MARK: - Observation

    private func startObserving(_ session: WorkoutSession) {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let next = withObservationTracking {
                    WatchActivityRelayBuilder.makeUpdate(from: session)
                } onChange: { /* re-loop */ }

                if next != self.lastPayload {
                    let now = Date()
                    let elapsed = now.timeIntervalSince(self.lastSentAt)
                    if elapsed < self.minUpdateInterval {
                        try? await Task.sleep(for: .milliseconds(Int((self.minUpdateInterval - elapsed) * 1000)))
                    }
                    self.send(.update(next))
                    self.lastPayload = next
                    self.lastSentAt = Date()
                }

                if case .summary = session.phase { return }
                if case .abandoned = session.phase { return }

                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handleIncoming(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.handleIncoming(userInfo) }
    }

    private func handleIncoming(_ dict: [String: Any]) {
        guard let data = dict["payload"] as? Data,
              let relay = try? JSONDecoder().decode(WatchActivityRelay.self, from: data) else { return }
        switch relay {
        case .intentDispatch(let p):
            applyIntent(p)
        default:
            break
        }
    }

    private func applyIntent(_ payload: WatchActivityRelay.IntentDispatchPayload) {
        guard let store, let session = store.activeSession,
              session.sessionId == payload.sessionId else { return }
        switch payload.kind {
        case .togglePause: store.togglePause()
        case .logSet: WatchQuickLog.completeNextSet(in: session)
        }
    }
}

/// Watch-side equivalent of QuickLogService — kept here (rather than in
/// FBBWorkoutKitCore) because the heuristics are presentation-layer.
@MainActor
enum WatchQuickLog {
    static func completeNextSet(in session: WorkoutSession) {
        guard let set = CursorAdvance.currentSet(session.cursor, in: session.day) else { return }
        let prescribedReps = set.repsMax ?? set.repsMin
        let lastWeight = session.setLog
            .last(where: { $0.setId.exerciseId == session.cursor.setId.exerciseId })
            .flatMap { $0.actualWeightKg }
        let entry = SetEntry(
            outcome: .completed,
            actualReps: prescribedReps,
            actualWeightKg: lastWeight,
            actualRpe: nil
        )
        session.completeSet(entry)
    }
}
