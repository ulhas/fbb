import Foundation
import WatchConnectivity

/// iOS-side WC receiver that drives `WorkoutLiveActivityController`
/// when a workout originates on the watch. Also dispatches Lock-Screen /
/// Dynamic Island button taps back to the watch when the session is
/// watch-owned.
@MainActor
final class LiveActivityRelayReceiver: NSObject, WCSessionDelegate {
    static let shared = LiveActivityRelayReceiver()

    private let wc: WCSession = .default
    weak var controller: WorkoutLiveActivityController?

    func bootstrap(controller: WorkoutLiveActivityController, bridge: LiveActivityBridge?) {
        guard WCSession.isSupported() else { return }
        self.controller = controller
        wc.delegate = self
        wc.activate()

        bridge?.relayIntentToWatch = { [weak self] kind, sessionId in
            self?.dispatchIntentToWatch(kind: kind, sessionId: sessionId)
        }
    }

    private func dispatchIntentToWatch(kind: WatchActivityRelay.IntentKind, sessionId: UUID) {
        let payload = WatchActivityRelay.IntentDispatchPayload(sessionId: sessionId, kind: kind)
        guard let data = try? JSONEncoder().encode(WatchActivityRelay.intentDispatch(payload)) else { return }
        let dict: [String: Any] = ["payload": data]
        if wc.isReachable {
            wc.sendMessage(dict, replyHandler: nil, errorHandler: { _ in
                self.wc.transferUserInfo(dict)
            })
        } else {
            wc.transferUserInfo(dict)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in await self.handleIncoming(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in await self.handleIncoming(userInfo) }
    }

    private func handleIncoming(_ dict: [String: Any]) async {
        guard let data = dict["payload"] as? Data,
              let relay = try? JSONDecoder().decode(WatchActivityRelay.self, from: data) else { return }
        guard let controller else { return }
        switch relay {
        case .start(let p):
            controller.startFromRelay(p)
        case .update(let p):
            await controller.updateFromRelay(p)
        case .pause(let id, let pausedAt):
            await controller.applyPausedAt(pausedAt, sessionId: id)
        case .end(let p):
            await controller.endFromRelay(sessionId: p.sessionId, final: p.finalState)
        case .abandon(let id):
            await controller.endFromRelay(sessionId: id, final: nil)
        case .intentDispatch:
            // Watch-originated intent dispatches don't reach iOS in v1.
            break
        }
    }
}
