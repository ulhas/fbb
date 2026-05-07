import Foundation

// Stable identifiers for the live workout session. These are *position
// tuples* — not server UUIDs — because the prescribed plan can be re-parsed
// and its rows can change identity, but a workout in flight is anchored to
// the snapshot the user started against. Section/group/exercise/set
// positions on `ParsedDay` are 1-indexed.

struct SectionId: Hashable, Codable, Sendable {
    let section: Int
}

struct GroupId: Hashable, Codable, Sendable {
    let section: Int
    let group: Int
}

struct ExerciseId: Hashable, Codable, Sendable {
    let section: Int
    let group: Int
    let exercise: Int
}

struct SetId: Hashable, Codable, Sendable {
    let section: Int
    let group: Int
    let exercise: Int
    let set: Int

    var exerciseId: ExerciseId { ExerciseId(section: section, group: group, exercise: exercise) }
    var groupId: GroupId { GroupId(section: section, group: group) }
    var sectionId: SectionId { SectionId(section: section) }
}

// Top-level phase of the screen. Keep this small — the mode-specific live
// state lives on `ActiveBlock` and rest lives on its own struct, neither
// of which belongs here.
enum SessionPhase: Codable, Hashable, Sendable {
    case preStart
    case running
    case summary
    case abandoned(reason: String)
}

// Unilateral set tracking. A set with `perSide == true` requires two
// completions (one per side) before its rest fires. The cursor carries
// this on a per-set basis.
enum PerSideProgress: String, Codable, Sendable, Hashable {
    case none      // not unilateral
    case firstSide // one side done
    case done      // both sides done (or non-unilateral set just completed)
}

// Outcome captured when the user taps "complete" / "skip" / "partial".
enum SetOutcome: String, Codable, Sendable, Hashable {
    case completed, skipped, partial
}

// One entry per logical set completion. Append-only — the engine never
// rewrites a log; undo decrements `userRoundsCompleted` etc. on the
// derived state and removes the most recent log entry.
struct SetLogEntry: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let setId: SetId
    let perSide: PerSideProgress?    // nil unless the set is per-side
    let outcome: SetOutcome
    let completedAt: Date
    let actualReps: Int?
    let actualWeightKg: Double?      // canonical kg
    let actualRpe: Double?
    let restTakenSeconds: Int?
}

// Per-group score for modes where the group has an aggregate result
// (AMRAP rounds + partial reps, for_time finish, density total reps).
struct GroupScore: Codable, Hashable, Sendable {
    let groupId: GroupId
    let prescriptionMode: String
    var rounds: Int?
    var partialReps: Int?
    var finishSeconds: Int?
    var totalReps: Int?
}

// Marker for when a section was entered/left, used to compute per-section
// time spent on the summary screen.
struct SectionTransition: Codable, Hashable, Sendable {
    let sectionId: SectionId
    let enteredAt: Date
    var leftAt: Date?
}

// Rest timer state. Lives off `WorkoutSession.restAfter` whenever the
// user has just completed a set (or round) that has rest defined. Rest
// can go negative (overtime) — the UI just renders the elapsed time in a
// different color.
struct RestState: Codable, Hashable, Sendable {
    let after: SetId?               // nil for between-rounds rest
    let plannedSeconds: Int
    let startedAt: Date

    func remainingSeconds(now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return plannedSeconds - elapsed
    }

    func isOvertime(now: Date) -> Bool {
        remainingSeconds(now: now) < 0
    }
}

/// Per-exercise duration timer for time-based sets (e.g., "30 sec
/// plank", "15 sec sprint"). Distinct from `RestState` and from
/// group-level `ActiveBlock` — this one runs *inside* an exercise row,
/// triggered by the user tapping Start.
///
/// State machine:
///   - idle: `startedAt == nil, completedAt == nil`
///   - running: `startedAt != nil, completedAt == nil`
///   - completed: `startedAt != nil, completedAt != nil`
struct ExerciseTimerState: Codable, Hashable, Sendable {
    let setId: SetId
    let plannedSeconds: Int
    var startedAt: Date?
    var completedAt: Date?

    var isRunning: Bool { startedAt != nil && completedAt == nil }
    var isCompleted: Bool { completedAt != nil }

    func remainingSeconds(now: Date) -> Int {
        guard let started = startedAt else { return plannedSeconds }
        if let completed = completedAt {
            let elapsed = Int(completed.timeIntervalSince(started))
            return max(0, plannedSeconds - elapsed)
        }
        let elapsed = Int(now.timeIntervalSince(started))
        return plannedSeconds - elapsed
    }

    func didFinish(now: Date) -> Bool {
        guard isRunning else { return false }
        return remainingSeconds(now: now) <= 0
    }
}

/// Inline rest row state. One per (group, after-exercise-position).
/// Created lazily when the user taps "Rest" on a rest row, ticks down,
/// auto-clears 5s past zero. Distinct from `RestState` (top-level
/// overlay) — this one renders inline.
struct InlineRestState: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let groupId: GroupId
    let afterExercisePosition: Int  // exercise that just ran
    let plannedSeconds: Int
    let startedAt: Date

    func remainingSeconds(now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return plannedSeconds - elapsed
    }
}
