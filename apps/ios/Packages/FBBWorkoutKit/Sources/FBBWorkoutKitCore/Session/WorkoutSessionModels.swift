import Foundation

// Stable identifiers for the live workout session. These are *position
// tuples* — not server UUIDs — because the prescribed plan can be re-parsed
// and its rows can change identity, but a workout in flight is anchored to
// the snapshot the user started against. Section/group/exercise/set
// positions on `ParsedDay` are 1-indexed.

public struct SectionId: Hashable, Codable, Sendable {
    public let section: Int
    public init(section: Int) { self.section = section }
}

public struct GroupId: Hashable, Codable, Sendable {
    public let section: Int
    public let group: Int
    public init(section: Int, group: Int) {
        self.section = section
        self.group = group
    }
}

public struct ExerciseId: Hashable, Codable, Sendable {
    public let section: Int
    public let group: Int
    public let exercise: Int
    public init(section: Int, group: Int, exercise: Int) {
        self.section = section
        self.group = group
        self.exercise = exercise
    }
}

public struct SetId: Hashable, Codable, Sendable {
    public let section: Int
    public let group: Int
    public let exercise: Int
    public let set: Int

    public init(section: Int, group: Int, exercise: Int, set: Int) {
        self.section = section
        self.group = group
        self.exercise = exercise
        self.set = set
    }

    public var exerciseId: ExerciseId { ExerciseId(section: section, group: group, exercise: exercise) }
    public var groupId: GroupId { GroupId(section: section, group: group) }
    public var sectionId: SectionId { SectionId(section: section) }
}

// Top-level phase of the screen. Keep this small — the mode-specific live
// state lives on `ActiveBlock` and rest lives on its own struct, neither
// of which belongs here.
public enum SessionPhase: Codable, Hashable, Sendable {
    case preStart
    case running
    case summary
    case abandoned(reason: String)
}

// Unilateral set tracking. A set with `perSide == true` requires two
// completions (one per side) before its rest fires. The cursor carries
// this on a per-set basis.
public enum PerSideProgress: String, Codable, Sendable, Hashable {
    case none      // not unilateral
    case firstSide // one side done
    case done      // both sides done (or non-unilateral set just completed)
}

// Outcome captured when the user taps "complete" / "skip" / "partial".
public enum SetOutcome: String, Codable, Sendable, Hashable {
    case completed, skipped, partial
}

// One entry per logical set completion. Append-only — the engine never
// rewrites a log; undo decrements `userRoundsCompleted` etc. on the
// derived state and removes the most recent log entry.
public struct SetLogEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let setId: SetId
    public let perSide: PerSideProgress?    // nil unless the set is per-side
    public let outcome: SetOutcome
    public let completedAt: Date
    public let actualReps: Int?
    public let actualWeightKg: Double?      // canonical kg
    public let actualRpe: Double?
    public let restTakenSeconds: Int?

    public init(
        id: UUID,
        setId: SetId,
        perSide: PerSideProgress?,
        outcome: SetOutcome,
        completedAt: Date,
        actualReps: Int?,
        actualWeightKg: Double?,
        actualRpe: Double?,
        restTakenSeconds: Int?
    ) {
        self.id = id
        self.setId = setId
        self.perSide = perSide
        self.outcome = outcome
        self.completedAt = completedAt
        self.actualReps = actualReps
        self.actualWeightKg = actualWeightKg
        self.actualRpe = actualRpe
        self.restTakenSeconds = restTakenSeconds
    }
}

// Per-group score for modes where the group has an aggregate result
// (AMRAP rounds + partial reps, for_time finish, density total reps).
public struct GroupScore: Codable, Hashable, Sendable {
    public let groupId: GroupId
    public let prescriptionMode: String
    public var rounds: Int?
    public var partialReps: Int?
    public var finishSeconds: Int?
    public var totalReps: Int?

    public init(
        groupId: GroupId,
        prescriptionMode: String,
        rounds: Int? = nil,
        partialReps: Int? = nil,
        finishSeconds: Int? = nil,
        totalReps: Int? = nil
    ) {
        self.groupId = groupId
        self.prescriptionMode = prescriptionMode
        self.rounds = rounds
        self.partialReps = partialReps
        self.finishSeconds = finishSeconds
        self.totalReps = totalReps
    }
}

// Marker for when a section was entered/left, used to compute per-section
// time spent on the summary screen.
public struct SectionTransition: Codable, Hashable, Sendable {
    public let sectionId: SectionId
    public let enteredAt: Date
    public var leftAt: Date?

    public init(sectionId: SectionId, enteredAt: Date, leftAt: Date? = nil) {
        self.sectionId = sectionId
        self.enteredAt = enteredAt
        self.leftAt = leftAt
    }
}

// Rest timer state. Lives off `WorkoutSession.restAfter` whenever the
// user has just completed a set (or round) that has rest defined. Rest
// can go negative (overtime) — the UI just renders the elapsed time in a
// different color.
public struct RestState: Codable, Hashable, Sendable {
    public let after: SetId?               // nil for between-rounds rest
    public let plannedSeconds: Int
    public let startedAt: Date

    public init(after: SetId?, plannedSeconds: Int, startedAt: Date) {
        self.after = after
        self.plannedSeconds = plannedSeconds
        self.startedAt = startedAt
    }

    public func remainingSeconds(now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return plannedSeconds - elapsed
    }

    public func isOvertime(now: Date) -> Bool {
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
public struct ExerciseTimerState: Codable, Hashable, Sendable {
    public let setId: SetId
    public let plannedSeconds: Int
    public var startedAt: Date?
    public var completedAt: Date?

    public init(setId: SetId, plannedSeconds: Int, startedAt: Date? = nil, completedAt: Date? = nil) {
        self.setId = setId
        self.plannedSeconds = plannedSeconds
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public var isRunning: Bool { startedAt != nil && completedAt == nil }
    public var isCompleted: Bool { completedAt != nil }

    public func remainingSeconds(now: Date) -> Int {
        guard let started = startedAt else { return plannedSeconds }
        if let completed = completedAt {
            let elapsed = Int(completed.timeIntervalSince(started))
            return max(0, plannedSeconds - elapsed)
        }
        let elapsed = Int(now.timeIntervalSince(started))
        return plannedSeconds - elapsed
    }

    public func didFinish(now: Date) -> Bool {
        guard isRunning else { return false }
        return remainingSeconds(now: now) <= 0
    }
}

/// Inline rest row state. One per (group, after-exercise-position).
/// Created lazily when the user taps "Rest" on a rest row, ticks down,
/// auto-clears 5s past zero. Distinct from `RestState` (top-level
/// overlay) — this one renders inline.
public struct InlineRestState: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let groupId: GroupId
    public let afterExercisePosition: Int  // exercise that just ran
    public let plannedSeconds: Int
    public let startedAt: Date

    public init(id: UUID, groupId: GroupId, afterExercisePosition: Int, plannedSeconds: Int, startedAt: Date) {
        self.id = id
        self.groupId = groupId
        self.afterExercisePosition = afterExercisePosition
        self.plannedSeconds = plannedSeconds
        self.startedAt = startedAt
    }

    public func remainingSeconds(now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return plannedSeconds - elapsed
    }
}
