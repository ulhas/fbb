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
struct PersistedSession: Codable {
    let sessionId: UUID
    let trackCode: String
    let weekStartsOn: String
    let scheduledOn: String
    let day: ParsedDay
    let startedAt: Date?
    let endedAt: Date?
    let pausedAccumulatedSeconds: TimeInterval
    let phase: SessionPhase
    let cursor: Cursor
    let activeBlock: ActiveBlock?
    let restAfter: RestState?
    let setLog: [SetLogEntry]
    let groupScores: [GroupId: GroupScore]
    let sectionTransitions: [SectionTransition]
    let notes: String
    let weightUnit: WeightUnit
    let snapshotAt: Date
    let pendingSync: Bool
}

@MainActor
enum SessionPersistence {
    private static let keyPrefix = "fbb.activeWorkoutSession.v1."
    private static let resumeMaxAge: TimeInterval = 24 * 60 * 60

    static func snapshot(_ session: WorkoutSession, pendingSync: Bool = false) {
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

    static func clear(_ sessionId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: sessionId))
    }

    /// Find the most recently snapshotted session that hasn't been
    /// cleared and is < 24h old. Used to offer "resume" on app launch.
    static func loadActive() -> PersistedSession? {
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
    static func loadPendingSync() -> [PersistedSession] {
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
