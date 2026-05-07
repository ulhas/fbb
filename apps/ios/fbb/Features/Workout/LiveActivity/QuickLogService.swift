import Foundation

/// Quick-log path used by the Live Activity "Log Set" button. The user
/// has no input UI on the lock screen, so we accept the prescribed reps
/// and reuse the most recent weight logged for this exercise.
@MainActor
enum QuickLogService {
    static func completeNextSet(in session: WorkoutSession) {
        guard let set = CursorAdvance.currentSet(session.cursor, in: session.day) else { return }

        let prescribedReps: Int? = set.repsMax ?? set.repsMin
        let lastWeightForExercise = session.setLog
            .last(where: { $0.setId.exerciseId == session.cursor.setId.exerciseId })
            .flatMap { $0.actualWeightKg }

        let entry = SetEntry(
            outcome: .completed,
            actualReps: prescribedReps,
            actualWeightKg: lastWeightForExercise,
            actualRpe: nil
        )
        session.completeSet(entry)
    }
}
