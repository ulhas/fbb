import Foundation

/// Bridge between the Live-Activity App Intents (which post
/// `NotificationCenter` events from `perform()`) and the running
/// `WorkoutStore`. `LiveActivityIntent.perform()` runs in the *app's*
/// process, so plain in-process notifications are sufficient — no
/// Darwin / App Group plumbing needed.
///
/// Why not have the intent call into this type directly? The intent
/// files live in the widget extension target. Routing through
/// notifications keeps the widget extension free of any
/// `FBBWorkoutKitCore` dependency.
@MainActor
final class LiveActivityBridge {
    static var shared: LiveActivityBridge?

    static let togglePauseNotification = Notification.Name("fbb.liveActivity.togglePause")
    static let logSetNotification      = Notification.Name("fbb.liveActivity.logSet")

    weak var store: WorkoutStore?
    /// Set by the iOS WatchConnectivity receiver. When the active session
    /// originated on the watch, intent taps must be relayed back to the
    /// watch instead of mutating a non-existent iPhone-side session.
    var sessionOriginIsWatch: Bool = false
    /// Closure that ships an intent dispatch back to the watch via WC.
    var relayIntentToWatch: ((WatchActivityRelay.IntentKind, UUID) -> Void)?

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: Self.togglePauseNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.togglePauseFromIntent() }
        })
        observers.append(center.addObserver(
            forName: Self.logSetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.logCurrentSetFromIntent() }
        })
    }

    deinit {
        let center = NotificationCenter.default
        for o in observers { center.removeObserver(o) }
    }

    private func togglePauseFromIntent() {
        guard let store, let session = store.activeSession else { return }
        if sessionOriginIsWatch {
            relayIntentToWatch?(.togglePause, session.sessionId)
        } else {
            store.togglePause()
        }
    }

    private func logCurrentSetFromIntent() {
        guard let store, let session = store.activeSession else { return }
        if sessionOriginIsWatch {
            relayIntentToWatch?(.logSet, session.sessionId)
        } else {
            QuickLogService.completeNextSet(in: session)
        }
    }
}
