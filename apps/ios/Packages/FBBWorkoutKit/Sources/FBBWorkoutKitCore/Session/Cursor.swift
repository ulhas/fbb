import Foundation

// Where the user currently is in the prescribed plan. The cursor advances
// only on user action (tap "complete", tap "skip", "next round"), never
// on a clock tick. Mutating the cursor is the only way to traverse the
// session — every other piece of state derives from it.
public struct Cursor: Codable, Hashable, Sendable {
    public var sectionPosition: Int
    public var groupPosition: Int
    public var exercisePosition: Int
    public var setPosition: Int
    public var perSideProgress: PerSideProgress

    public static func start(in day: ParsedDay) -> Cursor {
        guard let firstSection = day.sections.first,
              let firstGroup = firstSection.groups.first,
              let firstExercise = firstGroup.exercises.first,
              let firstSet = firstExercise.sets.first else {
            // Defensive: a `kind == .rest` day has no sections. The engine
            // shouldn't be started for those, but if it is we fall back to
            // a sentinel cursor that the UI will treat as "nothing to do".
            return Cursor(
                sectionPosition: 0, groupPosition: 0,
                exercisePosition: 0, setPosition: 0,
                perSideProgress: .none
            )
        }
        let isUnilateral = firstSet.perSide
        return Cursor(
            sectionPosition: firstSection.position,
            groupPosition: firstGroup.position,
            exercisePosition: firstExercise.position,
            setPosition: firstSet.position,
            perSideProgress: isUnilateral ? .none : .none
        )
    }

    public var setId: SetId {
        SetId(
            section: sectionPosition,
            group: groupPosition,
            exercise: exercisePosition,
            set: setPosition
        )
    }

    public var groupId: GroupId {
        GroupId(section: sectionPosition, group: groupPosition)
    }

    public var sectionId: SectionId {
        SectionId(section: sectionPosition)
    }
}

// Pure functions that find adjacent positions in the plan. The engine
// drives the cursor through these on user actions; UI never calls them
// directly.
public enum CursorAdvance {
    /// The next set after `cursor` in plan order. Skips per-side increment
    /// since this is for moving past a fully-completed set; per-side state
    /// is handled by the caller before calling here.
    /// Returns `nil` when the user is at the end of the workout.
    public static func next(after cursor: Cursor, in day: ParsedDay) -> Cursor? {
        guard let section = day.sections.first(where: { $0.position == cursor.sectionPosition }),
              let group = section.groups.first(where: { $0.position == cursor.groupPosition }),
              let exercise = group.exercises.first(where: { $0.position == cursor.exercisePosition }) else {
            return nil
        }

        // Try next set in the same exercise
        if let next = exercise.sets.first(where: { $0.position > cursor.setPosition }) {
            return Cursor(
                sectionPosition: cursor.sectionPosition,
                groupPosition: cursor.groupPosition,
                exercisePosition: cursor.exercisePosition,
                setPosition: next.position,
                perSideProgress: next.perSide ? .none : .none
            )
        }

        // Next exercise in the same group
        if let nextExercise = group.exercises.first(where: { $0.position > cursor.exercisePosition }),
           let firstSet = nextExercise.sets.first {
            return Cursor(
                sectionPosition: cursor.sectionPosition,
                groupPosition: cursor.groupPosition,
                exercisePosition: nextExercise.position,
                setPosition: firstSet.position,
                perSideProgress: firstSet.perSide ? .none : .none
            )
        }

        // Next group in the same section
        if let nextGroup = section.groups.first(where: { $0.position > cursor.groupPosition }),
           let firstExercise = nextGroup.exercises.first,
           let firstSet = firstExercise.sets.first {
            return Cursor(
                sectionPosition: cursor.sectionPosition,
                groupPosition: nextGroup.position,
                exercisePosition: firstExercise.position,
                setPosition: firstSet.position,
                perSideProgress: firstSet.perSide ? .none : .none
            )
        }

        // Next section
        if let nextSection = day.sections.first(where: { $0.position > cursor.sectionPosition }),
           let firstGroup = nextSection.groups.first,
           let firstExercise = firstGroup.exercises.first,
           let firstSet = firstExercise.sets.first {
            return Cursor(
                sectionPosition: nextSection.position,
                groupPosition: firstGroup.position,
                exercisePosition: firstExercise.position,
                setPosition: firstSet.position,
                perSideProgress: firstSet.perSide ? .none : .none
            )
        }

        return nil
    }

    /// True when this set is the last one in the plan in DFS order.
    public static func isLastSet(_ cursor: Cursor, in day: ParsedDay) -> Bool {
        next(after: cursor, in: day) == nil
    }

    /// Resolve the prescribed set the cursor points at, if any.
    public static func currentSet(_ cursor: Cursor, in day: ParsedDay) -> ParsedSet? {
        currentExercise(cursor, in: day)?
            .sets.first(where: { $0.position == cursor.setPosition })
    }

    public static func currentExercise(_ cursor: Cursor, in day: ParsedDay) -> ParsedExercise? {
        currentGroup(cursor, in: day)?
            .exercises.first(where: { $0.position == cursor.exercisePosition })
    }

    public static func currentGroup(_ cursor: Cursor, in day: ParsedDay) -> ParsedGroup? {
        currentSection(cursor, in: day)?
            .groups.first(where: { $0.position == cursor.groupPosition })
    }

    public static func currentSection(_ cursor: Cursor, in day: ParsedDay) -> ParsedSection? {
        day.sections.first(where: { $0.position == cursor.sectionPosition })
    }

    /// Whether the *current exercise* is chained into the next (superset).
    /// If true and the user has more sets in the next exercise, rest is
    /// suppressed and a "rotate to next" cue is shown instead.
    public static func isChainedToNext(_ cursor: Cursor, in day: ParsedDay) -> Bool {
        guard let ex = currentExercise(cursor, in: day) else { return false }
        return ex.chainedIntoNext
    }
}
