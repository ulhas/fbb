import Foundation
import Observation

// The single @Observable engine that drives everything on the workout
// detail screen. Internal contract:
//
//   - Plan (`day`) is immutable for the lifetime of the session.
//   - Cursor is mutated only by user actions (`completeSet`, `skipSet`,
//     `incrementRound`, etc.).
//   - Wall-clock anchors (`startedAt`, `pausedAccumulatedSeconds`,
//     `activeBlock.*.startedAt`) plus the current `Date` are the only
//     inputs to derived UI numbers.
//   - The engine takes a `tick(_ now:)` from `SessionTicker` once a
//     second; tick recomputes derived state and republishes.
//
// The engine is `@MainActor` and is held by `WorkoutDetailView`'s
// `@State`, so SwiftUI observes its property changes for free.
@Observable
@MainActor
public final class WorkoutSession {
    // Inputs (immutable)
    public let day: ParsedDay
    public let trackCode: String
    public let weekStartsOn: String
    public let scheduledOn: String
    public let sessionId: UUID
    /// Optional human-readable track name (e.g. "Pump", "Build"). Carried
    /// here so the Live Activity / lock-screen surfaces can render a title
    /// without having to re-resolve from track metadata.
    public let trackDisplayName: String?

    // Time anchors
    public private(set) var startedAt: Date?
    public private(set) var endedAt: Date?
    public private(set) var pausedAccumulatedSeconds: TimeInterval = 0
    public private(set) var pauseStartedAt: Date?

    // Phase + cursor + block
    public var phase: SessionPhase = .preStart
    public var cursor: Cursor
    public var activeBlock: ActiveBlock?
    public var restAfter: RestState?

    // Logs (append-only-ish)
    public var setLog: [SetLogEntry] = []
    public var groupScores: [GroupId: GroupScore] = [:]
    public var sectionTransitions: [SectionTransition] = []

    // Per-exercise duration timers (time-based sets) and inline rests.
    public var exerciseTimers: [SetId: ExerciseTimerState] = [:]
    public var inlineRests: [InlineRestState] = []

    // User input
    public var notes: String = ""
    public var weightUnit: WeightUnit = .kg

    // UI hint: ticks every second so views observing a `tick` property
    // re-render even when only derived values changed. Using a counter
    // keeps Equatable checks cheap.
    public var tickCounter: Int = 0

    public init(
        day: ParsedDay,
        trackCode: String,
        weekStartsOn: String,
        scheduledOn: String,
        sessionId: UUID = UUID(),
        weightUnit: WeightUnit = .kg,
        trackDisplayName: String? = nil
    ) {
        self.day = day
        self.trackCode = trackCode
        self.weekStartsOn = weekStartsOn
        self.scheduledOn = scheduledOn
        self.sessionId = sessionId
        self.weightUnit = weightUnit
        self.trackDisplayName = trackDisplayName
        self.cursor = Cursor.start(in: day)
    }

    // MARK: - Phase transitions

    public func startWorkout(now: Date = Date()) {
        guard phase == .preStart else { return }
        startedAt = now
        phase = .running

        // Mark the first section as entered.
        sectionTransitions.append(
            SectionTransition(
                sectionId: cursor.sectionId,
                enteredAt: now,
                leftAt: nil
            )
        )

        // Build the ActiveBlock for whichever group the cursor sits in.
        rebuildActiveBlock(now: now)
    }

    public var isPaused: Bool { pauseStartedAt != nil }

    /// Music-player-style pause: freezes the total elapsed clock and
    /// every wall-clock-anchored timer (group block, rest, inline
    /// rests, per-exercise duration timers). Resume shifts every anchor
    /// forward by the paused duration so the timers think no time
    /// passed.
    public func pauseWorkout(now: Date = Date()) {
        guard phase == .running, pauseStartedAt == nil else { return }
        pauseStartedAt = now
    }

    public func resumeWorkout(now: Date = Date()) {
        guard let pausedAt = pauseStartedAt else { return }
        let delta = now.timeIntervalSince(pausedAt)
        pausedAccumulatedSeconds += delta
        pauseStartedAt = nil

        // Shift all wall-clock-anchored timers forward by `delta`.
        if let block = activeBlock {
            activeBlock = block.shiftedForward(by: delta)
        }
        if let rest = restAfter {
            restAfter = RestState(
                after: rest.after,
                plannedSeconds: rest.plannedSeconds,
                startedAt: rest.startedAt.addingTimeInterval(delta)
            )
        }
        inlineRests = inlineRests.map { rest in
            InlineRestState(
                id: rest.id,
                groupId: rest.groupId,
                afterExercisePosition: rest.afterExercisePosition,
                plannedSeconds: rest.plannedSeconds,
                startedAt: rest.startedAt.addingTimeInterval(delta)
            )
        }
        for (id, t) in exerciseTimers where t.isRunning {
            var shifted = t
            shifted.startedAt = t.startedAt.map { $0.addingTimeInterval(delta) }
            exerciseTimers[id] = shifted
        }
    }

    public func endWorkout(now: Date = Date()) {
        guard phase == .running else { return }
        // Settle any in-flight pause first so totalElapsed math is clean.
        if pauseStartedAt != nil { resumeWorkout(now: now) }
        endedAt = now
        // Stamp the last section transition's leftAt
        if let idx = sectionTransitions.indices.last {
            sectionTransitions[idx].leftAt = now
        }
        phase = .summary
        activeBlock = nil
        restAfter = nil
    }

    public func abandonWorkout(reason: String, now: Date = Date()) {
        endedAt = now
        if let idx = sectionTransitions.indices.last {
            sectionTransitions[idx].leftAt = now
        }
        phase = .abandoned(reason: reason)
        activeBlock = nil
        restAfter = nil
    }

    // MARK: - Set actions

    /// Mark the current set complete. Captures actual reps/weight/RPE
    /// from `entry`, advances the cursor, and (unless a superset chain is
    /// in progress) opens a rest timer for the post-set rest interval.
    public func completeSet(_ entry: SetEntry, now: Date = Date()) {
        guard phase == .running else { return }
        guard let prescribed = CursorAdvance.currentSet(cursor, in: day) else { return }

        // For per-side sets, a single "complete" tap finishes one side
        // first, then the second. The cursor stays put after the first
        // side; the second side advances.
        let isUnilateral = prescribed.perSide
        let perSideAfter: PerSideProgress?

        if isUnilateral {
            switch cursor.perSideProgress {
            case .none:
                // First side just done. Stay on this set, await the second.
                cursor.perSideProgress = .firstSide
                perSideAfter = .firstSide
                // Log the first-side completion but don't open rest yet.
                appendLog(
                    setId: cursor.setId,
                    perSide: .firstSide,
                    outcome: entry.outcome,
                    completedAt: now,
                    entry: entry
                )
                return
            case .firstSide:
                cursor.perSideProgress = .done
                perSideAfter = .done
            case .done:
                perSideAfter = .done
            }
        } else {
            perSideAfter = nil
        }

        appendLog(
            setId: cursor.setId,
            perSide: perSideAfter,
            outcome: entry.outcome,
            completedAt: now,
            entry: entry
        )

        advanceCursorAfterSet(prescribed: prescribed, now: now)
    }

    /// Mark the current set skipped. Same advance behavior as completing,
    /// but no rest timer fires.
    public func skipSet(now: Date = Date()) {
        guard phase == .running else { return }
        guard let prescribed = CursorAdvance.currentSet(cursor, in: day) else { return }

        appendLog(
            setId: cursor.setId,
            perSide: prescribed.perSide ? .done : nil,
            outcome: .skipped,
            completedAt: now,
            entry: SetEntry(
                outcome: .skipped,
                actualReps: nil,
                actualWeightKg: nil,
                actualRpe: nil
            )
        )
        advanceCursorAfterSet(prescribed: prescribed, now: now, suppressRest: true)
    }

    /// Undo the most recent set log entry. Engine-only — no UI button
    /// for this in v1, but the back-stack support is in place.
    public func undoLastSet() {
        guard !setLog.isEmpty else { return }
        let removed = setLog.removeLast()
        // Rewind cursor to the removed entry's set; the next "complete" will
        // re-log it.
        cursor = Cursor(
            sectionPosition: removed.setId.section,
            groupPosition: removed.setId.group,
            exercisePosition: removed.setId.exercise,
            setPosition: removed.setId.set,
            perSideProgress: removed.perSide == .firstSide ? .none : .none
        )
        restAfter = nil
    }

    // MARK: - Group score actions (AMRAP / for-time / density)

    public func incrementGroupRound() {
        guard case let .capCountdown(state) = activeBlock else { return }
        var next = state
        next.userRoundsCompleted += 1
        activeBlock = .capCountdown(next)
        upsertGroupScore(for: state.groupId, mode: currentGroupMode()) { score in
            score.rounds = next.userRoundsCompleted
        }
    }

    public func decrementGroupRound() {
        guard case let .capCountdown(state) = activeBlock else { return }
        var next = state
        next.userRoundsCompleted = max(0, next.userRoundsCompleted - 1)
        activeBlock = .capCountdown(next)
        upsertGroupScore(for: state.groupId, mode: currentGroupMode()) { score in
            score.rounds = next.userRoundsCompleted
        }
    }

    public func setGroupPartialReps(_ reps: Int) {
        guard case let .capCountdown(state) = activeBlock else { return }
        var next = state
        next.userPartialReps = max(0, reps)
        activeBlock = .capCountdown(next)
        upsertGroupScore(for: state.groupId, mode: currentGroupMode()) { score in
            score.partialReps = next.userPartialReps
        }
    }

    /// for_time: user taps "Finish" to record their finish time.
    public func finishForTime(now: Date = Date()) {
        guard case let .capCountdown(state) = activeBlock else { return }
        let finish = state.elapsedSeconds(now: now)
        upsertGroupScore(for: state.groupId, mode: currentGroupMode()) { score in
            score.finishSeconds = finish
        }
        // Advance to the next group: jump cursor past everything in this group.
        skipToNextGroup(now: now)
    }

    /// Skip the rest of the current group — useful for "I've done enough
    /// rounds in this AMRAP, move on" in a multi-group section.
    public func skipToNextGroup(now: Date = Date()) {
        guard let section = CursorAdvance.currentSection(cursor, in: day),
              let nextGroup = section.groups.first(where: { $0.position > cursor.groupPosition }) else {
            // No next group in this section — try next section.
            advanceToNextSection(now: now)
            return
        }
        guard let firstExercise = nextGroup.exercises.first,
              let firstSet = firstExercise.sets.first else { return }
        cursor = Cursor(
            sectionPosition: section.position,
            groupPosition: nextGroup.position,
            exercisePosition: firstExercise.position,
            setPosition: firstSet.position,
            perSideProgress: .none
        )
        rebuildActiveBlock(now: now)
        restAfter = nil
    }

    public func dismissRest(now: Date = Date()) {
        restAfter = nil
    }

    public func extendRest(by seconds: Int, now: Date = Date()) {
        guard let r = restAfter else { return }
        restAfter = RestState(
            after: r.after,
            plannedSeconds: r.plannedSeconds + seconds,
            startedAt: r.startedAt
        )
    }

    /// Open a rest timer on demand (no preceding set required) — the watch
    /// uses this when the user wants to time a manual rest between
    /// exercises and the prescribed set didn't carry a `restAfterSeconds`.
    /// Replaces any existing rest.
    public func startRest(plannedSeconds: Int, now: Date = Date()) {
        let bounded = max(1, plannedSeconds)
        restAfter = RestState(
            after: cursor.setId,
            plannedSeconds: bounded,
            startedAt: now
        )
    }

    // MARK: - Per-exercise timer actions

    /// Start the duration timer on the set the cursor is pointing at —
    /// or any visible time-based set the user taps Start on. We let the
    /// caller pass the SetId so users can pre-start a later round's
    /// timer; only the cursor's set drives advancement.
    public func startExerciseTimer(setId: SetId, plannedSeconds: Int, now: Date = Date()) {
        var state = exerciseTimers[setId]
            ?? ExerciseTimerState(
                setId: setId,
                plannedSeconds: plannedSeconds,
                startedAt: nil,
                completedAt: nil
            )
        state.startedAt = now
        state.completedAt = nil
        exerciseTimers[setId] = state
    }

    public func cancelExerciseTimer(setId: SetId) {
        exerciseTimers.removeValue(forKey: setId)
    }

    /// Mark a duration-based set complete. Logs as `.completed` with
    /// the planned duration as the captured "actualReps" (we re-purpose
    /// reps to mean "seconds" for time-kind sets — the wire payload
    /// keeps the same column).
    public func completeDurationSet(setId: SetId, now: Date = Date()) {
        var state = exerciseTimers[setId]
            ?? ExerciseTimerState(setId: setId, plannedSeconds: 0, startedAt: now, completedAt: nil)
        if state.startedAt == nil { state.startedAt = now }
        state.completedAt = now
        exerciseTimers[setId] = state

        // If this is the cursor's set, advance through the cursor.
        if cursor.setId == setId {
            let entry = SetEntry(
                outcome: .completed,
                actualReps: state.plannedSeconds, // seconds
                actualWeightKg: nil,
                actualRpe: nil
            )
            completeSet(entry, now: now)
        } else {
            // Out-of-cursor completion (user pre-tapped a future set's
            // timer): just append the log entry without advancing.
            setLog.append(
                SetLogEntry(
                    id: UUID(),
                    setId: setId,
                    perSide: nil,
                    outcome: .completed,
                    completedAt: now,
                    actualReps: state.plannedSeconds,
                    actualWeightKg: nil,
                    actualRpe: nil,
                    restTakenSeconds: nil
                )
            )
        }
    }

    // MARK: - Round / inline-rest actions

    /// Mark every set at this round position complete across every
    /// exercise in the cursor's current group. Skips already-logged
    /// sets. Used by the "Mark all complete" shortcut.
    public func markRoundComplete(round: Int, now: Date = Date()) {
        guard let section = CursorAdvance.currentSection(cursor, in: day),
              let group = CursorAdvance.currentGroup(cursor, in: day) else { return }
        for exercise in group.exercises {
            guard let set = exercise.sets.first(where: { $0.position == round }) else { continue }
            let setId = SetId(
                section: section.position,
                group: group.position,
                exercise: exercise.position,
                set: set.position
            )
            // Skip if already logged.
            if setLog.contains(where: { $0.setId == setId && $0.perSide != .firstSide }) {
                continue
            }
            // For time-based sets without a recorded actualReps, use
            // planned seconds as a fallback.
            let actualReps: Int? = {
                if set.repsKind == "time" {
                    return SessionMath.midpoint(
                        min: set.durationSecondsMin,
                        max: set.durationSecondsMax
                    )
                }
                return SessionMath.midpoint(min: set.repsMin, max: set.repsMax)
            }()
            setLog.append(
                SetLogEntry(
                    id: UUID(),
                    setId: setId,
                    perSide: set.perSide ? .done : nil,
                    outcome: .completed,
                    completedAt: now,
                    actualReps: actualReps,
                    actualWeightKg: nil,
                    actualRpe: nil,
                    restTakenSeconds: nil
                )
            )
        }
        // If the cursor was on this round, advance to the next round
        // (or next group if this was the last round).
        if cursor.setPosition == round, let next = CursorAdvance.next(after: cursor, in: day) {
            cursor = next
            rebuildActiveBlock(now: now)
        }
    }

    /// Start an inline rest row attached to a specific exercise within a
    /// group. Used by the "Rest 60 seconds" + Rest button pattern. The
    /// rest is independent of `restAfter` (top-level overlay) — we don't
    /// auto-dismiss the bottom-sheet rest when an inline rest is open.
    public func triggerInlineRest(
        groupId: GroupId,
        afterExercisePosition: Int,
        plannedSeconds: Int,
        now: Date = Date()
    ) {
        // Replace any existing inline rest for the same group/position.
        inlineRests.removeAll {
            $0.groupId == groupId && $0.afterExercisePosition == afterExercisePosition
        }
        inlineRests.append(
            InlineRestState(
                id: UUID(),
                groupId: groupId,
                afterExercisePosition: afterExercisePosition,
                plannedSeconds: plannedSeconds,
                startedAt: now
            )
        )
    }

    public func dismissInlineRest(_ id: UUID) {
        inlineRests.removeAll { $0.id == id }
    }

    // MARK: - Tick

    /// Called once per second by `SessionTicker`. Advances tick counter
    /// and lets observers re-pull derived values. Heavy logic stays out
    /// of here so the per-tick cost is constant.
    public func tick(_ now: Date = Date()) {
        guard phase == .running else { return }
        // While paused: bump the counter so paused-duration UI updates,
        // but don't auto-advance any expirations.
        if isPaused {
            tickCounter &+= 1
            return
        }
        tickCounter &+= 1

        // If the active rest expired and we're more than a few seconds
        // overtime, dismiss it automatically (the row already crossed
        // out; the user has moved on).
        if let r = restAfter, r.remainingSeconds(now: now) < -10 {
            restAfter = nil
        }

        // Auto-dismiss inline rests once they're 5s past zero.
        inlineRests.removeAll { $0.remainingSeconds(now: now) < -5 }

        // Per-exercise duration timers: when a running timer hits zero,
        // stamp `completedAt` so the UI flips to "tap to log". We do
        // *not* auto-log — the user might want to push past or skip.
        // Haptics are fired in the view layer when this transition is
        // observed (engine stays UI-side-effect free).
        for (id, state) in exerciseTimers where state.isRunning && state.didFinish(now: now) {
            var done = state
            done.completedAt = now
            exerciseTimers[id] = done
        }
    }

    // MARK: - Derived

    public func totalElapsed(now: Date = Date()) -> TimeInterval {
        guard let started = startedAt else { return 0 }
        let end = endedAt ?? now
        let raw = end.timeIntervalSince(started)
        let liveSincePause = pauseStartedAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, raw - pausedAccumulatedSeconds - liveSincePause)
    }

    public func totalElapsedSeconds(now: Date = Date()) -> Int {
        Int(totalElapsed(now: now))
    }

    // MARK: - Internals

    private func appendLog(
        setId: SetId,
        perSide: PerSideProgress?,
        outcome: SetOutcome,
        completedAt: Date,
        entry: SetEntry
    ) {
        setLog.append(
            SetLogEntry(
                id: UUID(),
                setId: setId,
                perSide: perSide,
                outcome: outcome,
                completedAt: completedAt,
                actualReps: entry.actualReps,
                actualWeightKg: entry.actualWeightKg,
                actualRpe: entry.actualRpe,
                restTakenSeconds: nil
            )
        )
    }

    private func advanceCursorAfterSet(
        prescribed: ParsedSet,
        now: Date,
        suppressRest: Bool = false
    ) {
        let priorSectionId = cursor.sectionId
        let priorGroupId = cursor.groupId
        let chained = CursorAdvance.isChainedToNext(cursor, in: day)

        guard let next = CursorAdvance.next(after: cursor, in: day) else {
            // End of plan — auto-end the workout.
            endWorkout(now: now)
            return
        }

        cursor = next

        // Section change
        if next.sectionId != priorSectionId {
            if let idx = sectionTransitions.indices.last {
                sectionTransitions[idx].leftAt = now
            }
            sectionTransitions.append(
                SectionTransition(
                    sectionId: next.sectionId,
                    enteredAt: now,
                    leftAt: nil
                )
            )
        }

        // Group change (rebuild the ActiveBlock)
        if next.groupId != priorGroupId {
            rebuildActiveBlock(now: now)
            restAfter = nil
            return
        }

        // Same group — open rest unless the chain says otherwise.
        if !suppressRest && !chained {
            if let plannedRest = SessionMath.midpoint(
                min: prescribed.restAfterSecondsMin,
                max: prescribed.restAfterSecondsMax
            ), plannedRest > 0 {
                restAfter = RestState(
                    after: cursor.setId,
                    plannedSeconds: plannedRest,
                    startedAt: now
                )
            } else {
                restAfter = nil
            }
        } else {
            restAfter = nil
        }
    }

    private func advanceToNextSection(now: Date) {
        guard let nextSection = day.sections.first(where: { $0.position > cursor.sectionPosition }),
              let firstGroup = nextSection.groups.first,
              let firstExercise = firstGroup.exercises.first,
              let firstSet = firstExercise.sets.first else {
            endWorkout(now: now)
            return
        }
        if let idx = sectionTransitions.indices.last {
            sectionTransitions[idx].leftAt = now
        }
        sectionTransitions.append(
            SectionTransition(
                sectionId: SectionId(section: nextSection.position),
                enteredAt: now,
                leftAt: nil
            )
        )
        cursor = Cursor(
            sectionPosition: nextSection.position,
            groupPosition: firstGroup.position,
            exercisePosition: firstExercise.position,
            setPosition: firstSet.position,
            perSideProgress: .none
        )
        rebuildActiveBlock(now: now)
        restAfter = nil
    }

    private func rebuildActiveBlock(now: Date) {
        guard let section = CursorAdvance.currentSection(cursor, in: day),
              let group = CursorAdvance.currentGroup(cursor, in: day) else {
            activeBlock = nil
            return
        }
        activeBlock = ActiveBlockReducer.make(
            for: group,
            in: section,
            startedAt: now
        )
    }

    private func currentGroupMode() -> String {
        CursorAdvance.currentGroup(cursor, in: day)?.prescriptionMode ?? "free"
    }

    private func upsertGroupScore(
        for groupId: GroupId,
        mode: String,
        update: (inout GroupScore) -> Void
    ) {
        var score = groupScores[groupId]
            ?? GroupScore(
                groupId: groupId,
                prescriptionMode: mode,
                rounds: nil,
                partialReps: nil,
                finishSeconds: nil,
                totalReps: nil
            )
        update(&score)
        groupScores[groupId] = score
    }

    private func isBlockExpired(_ block: ActiveBlock, now: Date) -> Bool {
        switch block {
        case .none: return false
        case .interval(let s): return s.isComplete(now: now)
        case .capCountdown(let s): return s.isExpired(now: now)
        case .tabata(let s): return s.isComplete(now: now)
        case .pyramid(let s): return s.isComplete(now: now)
        case .stopwatch: return false
        }
    }
}

// User-supplied input captured at "tap to complete" time. The view fills
// in defaults from the prescribed set; the user can override.
public struct SetEntry: Sendable {
    public var outcome: SetOutcome
    public var actualReps: Int?
    public var actualWeightKg: Double?
    public var actualRpe: Double?

    public init(
        outcome: SetOutcome,
        actualReps: Int? = nil,
        actualWeightKg: Double? = nil,
        actualRpe: Double? = nil
    ) {
        self.outcome = outcome
        self.actualReps = actualReps
        self.actualWeightKg = actualWeightKg
        self.actualRpe = actualRpe
    }

    public static let skipped = SetEntry(
        outcome: .skipped,
        actualReps: nil,
        actualWeightKg: nil,
        actualRpe: nil
    )
}

public enum WeightUnit: String, Codable, Sendable, Hashable, CaseIterable {
    case kg, lb

    public var displayLabel: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }
}
