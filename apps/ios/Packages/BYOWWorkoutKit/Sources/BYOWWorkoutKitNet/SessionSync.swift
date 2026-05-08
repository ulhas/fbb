import Foundation
import BYOWWorkoutKitCore

// Coordinates the post-workout sync. The path of least surprise:
//   1. User taps Save on the Summary screen.
//   2. WorkoutDetailView snapshots the session locally with
//      `pendingSync: true`, then awaits `SessionSync.upload(_:)`.
//   3. If 2xx — clear the local blob and pop. If anything fails — keep
//      the blob; the next foreground tick drains pending blobs through
//      `SessionSync.drainPending(api:)`.
//
// The simpler one-shot POST trades incremental sync for predictability:
// the server only ever sees a complete, internally-consistent session.

@MainActor
public enum SessionSync {
    public enum SyncResult: Sendable {
        case synced
        case keptLocal(APIError)
    }

    public static func upload(
        _ session: WorkoutSession,
        api: APIClient
    ) async -> SyncResult {
        // Snapshot first with pendingSync = true so a crash mid-POST
        // leaves a recoverable blob.
        SessionPersistence.snapshot(session, pendingSync: true)

        let payload = WorkoutSessionPayload.from(session)
        do {
            _ = try await api.postWorkoutSession(payload)
            SessionPersistence.clear(session.sessionId)
            return .synced
        } catch let error as APIError {
            return .keptLocal(error)
        } catch {
            return .keptLocal(.unknown(error.localizedDescription))
        }
    }

    /// Drain anything left over from previous failed syncs. Called from
    /// `WorkoutDetailView` `.task` and from the app's `scenePhase`
    /// handler. Best-effort and non-blocking — failures keep the blob
    /// for the next attempt.
    public static func drainPending(api: APIClient) async {
        let pending = SessionPersistence.loadPendingSync()
        for snap in pending {
            let payload = payload(from: snap)
            do {
                _ = try await api.postWorkoutSession(payload)
                SessionPersistence.clear(snap.sessionId)
            } catch {
                // Leave the blob — next attempt will retry.
            }
        }
    }

    private static func payload(from snap: PersistedSession) -> WorkoutSessionPayload {
        let status: String
        if case .abandoned = snap.phase { status = "abandoned" }
        else { status = "completed" }

        return WorkoutSessionPayload(
            clientSessionId: snap.sessionId,
            trackCode: snap.trackCode,
            scheduledOn: snap.scheduledOn,
            dayId: nil,
            startedAt: snap.startedAt ?? snap.snapshotAt,
            endedAt: snap.endedAt,
            totalElapsedSeconds: Int(
                (snap.endedAt ?? snap.snapshotAt)
                    .timeIntervalSince(snap.startedAt ?? snap.snapshotAt)
            ),
            status: status,
            notes: snap.notes.isEmpty ? nil : snap.notes,
            weightUnit: snap.weightUnit.rawValue,
            setLogs: snap.setLog.map { entry in
                WorkoutSessionPayload.SetLogPayload(
                    sectionPosition: entry.setId.section,
                    groupPosition: entry.setId.group,
                    exercisePosition: entry.setId.exercise,
                    setPosition: entry.setId.set,
                    perSide: entry.perSide.map { $0 == .firstSide ? "first" : "done" },
                    outcome: entry.outcome.rawValue,
                    actualReps: entry.actualReps,
                    actualWeightKg: entry.actualWeightKg,
                    actualRpe: entry.actualRpe,
                    restTakenSeconds: entry.restTakenSeconds,
                    completedAt: entry.completedAt
                )
            },
            groupScores: snap.groupScores.values.map { score in
                WorkoutSessionPayload.GroupScorePayload(
                    sectionPosition: score.groupId.section,
                    groupPosition: score.groupId.group,
                    prescriptionMode: score.prescriptionMode,
                    rounds: score.rounds,
                    partialReps: score.partialReps,
                    finishSeconds: score.finishSeconds,
                    totalReps: score.totalReps
                )
            }
        )
    }
}
