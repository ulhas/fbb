import Foundation
import Observation

// 1Hz tick driver for `WorkoutSession`. Keeps a single `Timer.publish`
// off the main run loop and forwards `Date.now` into the session every
// second. Sub-second visuals (countdown ring sweep, last-3-2-1 pulse)
// use `TimelineView(.periodic(from:by:0.1))` directly in their views —
// they don't go through this ticker.
@MainActor
final class SessionTicker {
    private weak var session: WorkoutSession?
    private var timer: Timer?

    init(session: WorkoutSession) {
        self.session = session
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.session?.tick(Date())
            }
        }
        // .common mode keeps it firing during scroll (otherwise the
        // default mode pauses ticks while a UIScrollView is dragging).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
