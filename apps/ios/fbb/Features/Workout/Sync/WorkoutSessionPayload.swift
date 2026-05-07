import Foundation

// Wire format for POST /workouts/sessions and the response. Snake_case is
// converted via JSONEncoder.keyEncodingStrategy = .convertToSnakeCase, so
// the iOS struct is camelCase. This struct round-trips to and from the
// server, so the same DTO is used to read history (GET /:id).

struct WorkoutSessionPayload: Codable, Hashable, Sendable {
    let clientSessionId: UUID
    let trackCode: String
    let scheduledOn: String
    let dayId: String?
    let startedAt: Date
    let endedAt: Date?
    let totalElapsedSeconds: Int
    let status: String         // "completed" | "abandoned"
    let notes: String?
    let weightUnit: String     // "kg" | "lb"
    let setLogs: [SetLogPayload]
    let groupScores: [GroupScorePayload]

    struct SetLogPayload: Codable, Hashable, Sendable {
        let sectionPosition: Int
        let groupPosition: Int
        let exercisePosition: Int
        let setPosition: Int
        let perSide: String?
        let outcome: String
        let actualReps: Int?
        let actualWeightKg: Double?
        let actualRpe: Double?
        let restTakenSeconds: Int?
        let completedAt: Date
    }

    struct GroupScorePayload: Codable, Hashable, Sendable {
        let sectionPosition: Int
        let groupPosition: Int
        let prescriptionMode: String
        let rounds: Int?
        let partialReps: Int?
        let finishSeconds: Int?
        let totalReps: Int?
    }
}

extension WorkoutSessionPayload {
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
