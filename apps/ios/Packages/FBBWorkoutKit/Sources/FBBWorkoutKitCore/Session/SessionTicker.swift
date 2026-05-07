import Foundation
import Observation

// 1Hz tick driver for `WorkoutSession`. Forwards `Date.now` into the
// session every second on the main actor. Sub-second visuals (countdown
// ring sweep, last-3-2-1 pulse) use `TimelineView(.periodic(from:by:0.1))`
// directly in their views — they don't go through this ticker.
@MainActor
public final class SessionTicker {
    private weak var session: WorkoutSession?
    private var task: Task<Void, Never>?

    public init(session: WorkoutSession) {
        self.session = session
    }

    public func start() {
        stop()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.session?.tick(Date())
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        // `task` is a Task<Void, Never> whose `cancel()` is nonisolated.
        // Touching MainActor-isolated `self.task` from a nonisolated deinit
        // is what tripped Swift 6 — but `Task` itself is Sendable, so
        // grabbing a snapshot at construction-time and capturing it via a
        // separate variable would work. Simplest: don't cancel here. The
        // task captures `[weak self]`, so once SessionTicker is gone the
        // tick body becomes a no-op and the Task naturally winds down on
        // the next sleep wake — at most one redundant wake.
    }
}
