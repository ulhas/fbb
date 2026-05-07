import Foundation

/// Pure descriptors that turn the engine's `(Cursor, ParsedDay, ActiveBlock?)`
/// triple into the human-readable strings the Live Activity (and any
/// other glanceable surface) renders. Kept here rather than in the iOS
/// app target so the watch's relay sender can produce the exact same
/// strings, and the iPhone-side controller never has to second-guess.
public enum CursorDescriptors {
    /// "Back Squat" / "Single-Arm Row" — the movement at the cursor.
    /// Returns `"—"` when the cursor has fallen off the plan.
    public static func currentExerciseName(cursor: Cursor, in day: ParsedDay) -> String {
        CursorAdvance.currentExercise(cursor, in: day)?.movementDisplayName ?? "—"
    }

    /// "Set 2 of 4" / "Set 1 of 1 · L" — set position within the current
    /// exercise, with a per-side hint when the set is unilateral.
    public static func setProgressLabel(cursor: Cursor, in day: ParsedDay) -> String {
        guard let exercise = CursorAdvance.currentExercise(cursor, in: day) else { return "" }
        let total = exercise.sets.count
        guard total > 0 else { return "" }
        let index = exercise.sets.firstIndex(where: { $0.position == cursor.setPosition })
        let position = (index ?? 0) + 1
        var label = "Set \(position) of \(total)"
        if let set = CursorAdvance.currentSet(cursor, in: day), set.perSide {
            let sideHint = cursor.perSideProgress == .firstSide ? " · R" : " · L"
            label += sideHint
        }
        return label
    }

    /// "AMRAP · 12:00" / "EMOM · 8 min" / "TABATA · 8 RDS" — short label
    /// for group-level prescriptions. `nil` for plain straight-set work.
    public static func groupModeLabel(activeBlock: ActiveBlock?) -> String? {
        guard let block = activeBlock else { return nil }
        switch block {
        case .none: return nil
        case .interval(let s):
            return "EMOM · \(s.totalRounds) RDS"
        case .capCountdown(let s):
            return "AMRAP · \(formatMinSec(seconds: s.capSeconds))"
        case .tabata(let s):
            return "TABATA · \(s.totalRounds) RDS"
        case .pyramid(let s):
            return "PYRAMID · \(formatMinSec(seconds: s.totalSeconds))"
        case .stopwatch:
            return "STOPWATCH"
        }
    }

    /// Total prescribed sets across the whole day. Used by the activity
    /// progress bar (`setsCompleted / setsTotal`).
    public static func totalSets(in day: ParsedDay) -> Int {
        day.sections.reduce(0) { acc, section in
            acc + section.groups.reduce(0) { acc2, group in
                acc2 + group.exercises.reduce(0) { $0 + $1.sets.count }
            }
        }
    }

    /// Sets the user has actually logged (skipped sets count too — they're
    /// resolved). Per-side first-side rows aren't double-counted because
    /// `completeSet` only appends the final entry on the second side.
    public static func setsCompleted(setLog: [SetLogEntry]) -> Int {
        setLog.count
    }

    private static func formatMinSec(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
