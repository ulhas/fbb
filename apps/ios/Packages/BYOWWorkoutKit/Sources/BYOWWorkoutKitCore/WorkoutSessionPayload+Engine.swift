import Foundation

// Factory for building WorkoutSessionPayload from the in-memory engine
// session. Lives next to the engine in Core; the base Codable struct is
// in WorkoutSessionPayload.swift.

public extension WorkoutSessionPayload {
    /// Build the wire payload from an in-memory session. The session must
    /// have completed its run (`endedAt` set, `phase == .summary`) — we
    /// don't post in-progress sessions.
    @MainActor
    static func from(_ session: WorkoutSession) -> WorkoutSessionPayload {
        let status: String
        if case .abandoned = session.phase {
            status = "abandoned"
        } else {
            status = "completed"
        }

        return WorkoutSessionPayload(
            clientSessionId: session.sessionId,
            trackCode: session.trackCode,
            scheduledOn: session.scheduledOn,
            dayId: nil,
            startedAt: session.startedAt ?? Date(),
            endedAt: session.endedAt,
            totalElapsedSeconds: session.totalElapsedSeconds(),
            status: status,
            notes: session.notes.isEmpty ? nil : session.notes,
            weightUnit: session.weightUnit.rawValue,
            setLogs: session.setLog.map { entry in
                SetLogPayload(
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
            groupScores: session.groupScores.values.map { score in
                GroupScorePayload(
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
