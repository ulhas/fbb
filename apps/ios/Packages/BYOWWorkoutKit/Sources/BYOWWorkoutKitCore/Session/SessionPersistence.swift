import Foundation

// Local crash-recovery snapshot of an in-progress workout. Single JSON
// blob in UserDefaults — one per active session, keyed by sessionId. We
// keep at most one active session at a time (the iOS UI doesn't let
// multiple workouts overlap), so finding the active blob is a scan of
// the keys with a known prefix.
//
// Snapshot is written on every state transition (set complete, round
// flip, phase change, scenePhase backgrounding) plus a 30s heartbeat
// from `WorkoutDetailView`. On launch, if a blob exists and is < 24h
// old, the Today screen offers a "Resume in-progress workout" banner
// (banner is a v1.1 follow-up; the engine support lands now).
public struct PersistedSession: Codable {
    public let sessionId: UUID
    public let trackCode: String
    public let weekStartsOn: String
    public let scheduledOn: String
    public let day: ParsedDay
    public let startedAt: Date?
    public let endedAt: Date?
    public let pausedAccumulatedSeconds: TimeInterval
    public let phase: SessionPhase
    public let cursor: Cursor
    public let activeBlock: ActiveBlock?
    public let restAfter: RestState?
    public let setLog: [SetLogEntry]
    public let groupScores: [GroupId: GroupScore]
    public let sectionTransitions: [SectionTransition]
    public let notes: String
    public let weightUnit: WeightUnit
    public let snapshotAt: Date
    public let pendingSync: Bool
}

@MainActor
public enum SessionPersistence {
    private static let keyPrefix = "byow.activeWorkoutSession.v1."
    private static let resumeMaxAge: TimeInterval = 24 * 60 * 60

    public static func snapshot(_ session: WorkoutSession, pendingSync: Bool = false) {
        let snap = PersistedSession(
            sessionId: session.sessionId,
            trackCode: session.trackCode,
            weekStartsOn: session.weekStartsOn,
            scheduledOn: session.scheduledOn,
            day: session.day,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            pausedAccumulatedSeconds: 0,
            phase: session.phase,
            cursor: session.cursor,
            activeBlock: session.activeBlock,
            restAfter: session.restAfter,
            setLog: session.setLog,
            groupScores: session.groupScores,
            sectionTransitions: session.sectionTransitions,
            notes: session.notes,
            weightUnit: session.weightUnit,
            snapshotAt: Date(),
            pendingSync: pendingSync
        )
        do {
            let data = try JSONEncoder().encode(snap)
            UserDefaults.standard.set(data, forKey: key(for: session.sessionId))
        } catch {
            // Persistence failure shouldn't crash the workout. Log
            // somewhere visible if we add logging later; for now, swallow.
        }
    }

    public static func clear(_ sessionId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: sessionId))
    }

    /// Find the most recently snapshotted session that hasn't been
    /// cleared and is < 24h old. Used to offer "resume" on app launch.
    public static func loadActive() -> PersistedSession? {
        let defaults = UserDefaults.standard
        var best: PersistedSession?
        for (k, v) in defaults.dictionaryRepresentation() where k.hasPrefix(keyPrefix) {
            guard let data = v as? Data else { continue }
            guard let snap = try? JSONDecoder().decode(PersistedSession.self, from: data) else {
                defaults.removeObject(forKey: k)
                continue
            }
            if Date().timeIntervalSince(snap.snapshotAt) > resumeMaxAge {
                defaults.removeObject(forKey: k)
                continue
            }
            if best == nil || snap.snapshotAt > (best?.snapshotAt ?? .distantPast) {
                best = snap
            }
        }
        return best
    }

    /// All blobs that the device thinks failed to sync after their
    /// workout ended. Sync layer drains this on `scenePhase == .active`.
    public static func loadPendingSync() -> [PersistedSession] {
        let defaults = UserDefaults.standard
        var out: [PersistedSession] = []
        for (k, v) in defaults.dictionaryRepresentation() where k.hasPrefix(keyPrefix) {
            guard let data = v as? Data else { continue }
            guard let snap = try? JSONDecoder().decode(PersistedSession.self, from: data) else {
                continue
            }
            if snap.pendingSync {
                out.append(snap)
            }
        }
        return out
    }

    private static func key(for id: UUID) -> String {
        keyPrefix + id.uuidString
    }
}
