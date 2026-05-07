import Foundation
import Observation
import FBBWorkoutKitCore
import FBBWorkoutKitNet

/// Slim watch-side workout state. Phase 1A only handles `straight_sets`-style
/// flow — walk through every (section, group, exercise, set), let the user
/// log reps + weight + RPE, take a rest, and finish. The full iOS engine
/// (AMRAP, EMOM, for-time, per-side unilateral, exercise timers, group
/// scoring, pause/resume math, persistence) is intentionally not mirrored
/// here; that arrives once the iOS WorkoutSession is itself extracted into
/// the shared package.
@Observable
@MainActor
final class WatchSessionStore {
    enum Phase: Equatable, Sendable {
        case idle
        case running
        case summary
        case posted
        case failed(String)
    }

    private(set) var sessionId = UUID()
    private(set) var day: ParsedDay?
    private(set) var trackCode: String?

    var phase: Phase = .idle
    var startedAt: Date?
    var endedAt: Date?

    /// Cursor: indexes into the day's nested arrays.
    private(set) var sectionIdx = 0
    private(set) var groupIdx = 0
    private(set) var exerciseIdx = 0
    private(set) var setIdx = 0

    /// When the user first arrived on the current exercise. Resets every
    /// time the cursor crosses an exercise boundary, so the Set page can
    /// display "you've spent 2:34 on this exercise."
    private(set) var exerciseStartedAt: Date?

    var setLogs: [LoggedSet] = []
    var notes: String = ""
    var weightUnit: WeightUnit = .kg

    /// Set if the user is currently resting after a logged set.
    var restEndsAt: Date?

    /// Tick counter — incremented every second while running so views that
    /// need to re-render (timers) can observe it.
    var tickCounter: Int = 0
    private var tickTask: Task<Void, Never>?

    var hasActiveSession: Bool {
        if case .running = phase { return true }
        return false
    }

    // MARK: - Lifecycle

    func start(day: ParsedDay, trackCode: String) {
        self.day = day
        self.trackCode = trackCode
        self.sessionId = UUID()
        self.startedAt = Date()
        self.endedAt = nil
        self.setLogs = []
        self.notes = ""
        self.weightUnit = .kg
        self.restEndsAt = nil
        self.phase = .running
        // Snap to the first valid (section, group, exercise, set) — protects
        // against days whose first section/group/exercise has no children.
        snapToFirstValidSet()
        exerciseStartedAt = Date()
        startTicker()
    }

    func end() {
        guard hasActiveSession else { return }
        endedAt = Date()
        phase = .summary
        stopTicker()
    }

    func abandon() {
        endedAt = Date()
        phase = .summary
        stopTicker()
    }

    /// Reset to idle after a successful POST (or after a discard).
    func reset() {
        day = nil
        trackCode = nil
        startedAt = nil
        endedAt = nil
        setLogs = []
        notes = ""
        restEndsAt = nil
        phase = .idle
        stopTicker()
    }

    // MARK: - Set logging

    func logCurrentSet(actualReps: Int?, actualWeightKg: Double?, actualRpe: Double?) {
        guard let setId = currentSetId else { return }
        let restSeconds = currentSet?.restAfterSecondsMin
        let log = LoggedSet(
            id: UUID(),
            setId: setId,
            outcome: .completed,
            actualReps: actualReps,
            actualWeightKg: actualWeightKg,
            actualRpe: actualRpe,
            restTakenSeconds: restSeconds,
            completedAt: Date()
        )
        setLogs.append(log)
        startRestIfNeeded(seconds: restSeconds)
        advanceCursor()
    }

    func skipCurrentSet() {
        guard let setId = currentSetId else { return }
        setLogs.append(
            LoggedSet(
                id: UUID(),
                setId: setId,
                outcome: .skipped,
                actualReps: nil,
                actualWeightKg: nil,
                actualRpe: nil,
                restTakenSeconds: nil,
                completedAt: Date()
            )
        )
        advanceCursor()
    }

    // MARK: - Rest

    func startRestIfNeeded(seconds: Int?) {
        if let s = seconds, s > 0 {
            restEndsAt = Date().addingTimeInterval(TimeInterval(s))
        }
    }

    func adjustRest(by deltaSeconds: Int) {
        guard let current = restEndsAt else { return }
        restEndsAt = current.addingTimeInterval(TimeInterval(deltaSeconds))
    }

    func skipRest() {
        restEndsAt = nil
    }

    var restRemainingSeconds: Int? {
        guard let end = restEndsAt else { return nil }
        return max(0, Int(end.timeIntervalSinceNow.rounded()))
    }

    var isResting: Bool { restEndsAt != nil }

    // MARK: - Cursor

    /// Walk forward from the current position to the next valid set,
    /// hopping past empty exercises / groups / sections. Auto-ends when no
    /// more valid sets remain. Tracks exercise crossings so the per-exercise
    /// timer can reset.
    func advanceCursor() {
        guard let day else { return }
        let priorSection = sectionIdx
        let priorExercise = exerciseIdx
        let priorGroup = groupIdx

        var s = sectionIdx, g = groupIdx, e = exerciseIdx, set = setIdx + 1

        while s < day.sections.count {
            let section = day.sections[s]
            if g >= section.groups.count { g = 0; s += 1; continue }
            let group = section.groups[g]
            if e >= group.exercises.count { e = 0; g += 1; continue }
            let exercise = group.exercises[e]
            if set >= exercise.sets.count { set = 0; e += 1; continue }
            sectionIdx = s; groupIdx = g; exerciseIdx = e; setIdx = set
            // Reset exercise timer if we crossed an exercise / group / section boundary.
            if s != priorSection || g != priorGroup || e != priorExercise {
                exerciseStartedAt = Date()
            }
            return
        }
        // No more sets — auto-end.
        end()
    }

    /// Move cursor to the first non-empty (section, group, exercise, set).
    /// Called from `start()` so an empty leading section doesn't strand the
    /// user on a screen with `currentSet == nil`.
    private func snapToFirstValidSet() {
        guard let day else { return }
        for (sIdx, section) in day.sections.enumerated() {
            for (gIdx, group) in section.groups.enumerated() {
                for (eIdx, exercise) in group.exercises.enumerated() {
                    if !exercise.sets.isEmpty {
                        sectionIdx = sIdx
                        groupIdx = gIdx
                        exerciseIdx = eIdx
                        setIdx = 0
                        return
                    }
                }
            }
        }
        // Day had no sets at all — nothing to do; current* accessors will
        // return nil and the UI will show its empty state.
        sectionIdx = 0; groupIdx = 0; exerciseIdx = 0; setIdx = 0
    }

    // MARK: - Derived: current set

    var currentSection: ParsedSection? {
        guard let day, sectionIdx < day.sections.count else { return nil }
        return day.sections[sectionIdx]
    }

    var currentGroup: ParsedGroup? {
        guard let s = currentSection, groupIdx < s.groups.count else { return nil }
        return s.groups[groupIdx]
    }

    var currentExercise: ParsedExercise? {
        guard let g = currentGroup, exerciseIdx < g.exercises.count else { return nil }
        return g.exercises[exerciseIdx]
    }

    var currentSet: ParsedSet? {
        guard let e = currentExercise, setIdx < e.sets.count else { return nil }
        return e.sets[setIdx]
    }

    var currentSetId: SetId? {
        guard let s = currentSection, let g = currentGroup,
              let e = currentExercise, let st = currentSet
        else { return nil }
        return SetId(
            section: s.position,
            group: g.position,
            exercise: e.position,
            set: st.position
        )
    }

    var totalSetsInCurrentExercise: Int {
        currentExercise?.sets.count ?? 0
    }

    /// 1-based exercise number across the whole section (groups flattened),
    /// for the "Ex 2 of 4" indicator. Counts only exercises that have at
    /// least one set, so empty placeholders don't pollute the position.
    var exercisePositionInSection: Int? {
        guard let section = currentSection,
              let currentEx = currentExercise else { return nil }
        var pos = 0
        for group in section.groups {
            for exercise in group.exercises {
                guard !exercise.sets.isEmpty else { continue }
                pos += 1
                if exercise.position == currentEx.position
                   && group.position == (currentGroup?.position ?? -1) {
                    return pos
                }
            }
        }
        return nil
    }

    var totalExercisesInSection: Int {
        currentSection?.groups.reduce(0) { acc, group in
            acc + group.exercises.filter { !$0.sets.isEmpty }.count
        } ?? 0
    }

    /// Peek at the next exercise the cursor will land on (different name
    /// from current). Returns nil at the end of the day.
    var nextExerciseName: String? {
        guard let day else { return nil }
        var s = sectionIdx, g = groupIdx, e = exerciseIdx
        let currentName = currentExercise?.movementDisplayName

        // Walk exercise by exercise.
        while s < day.sections.count {
            let section = day.sections[s]
            if g >= section.groups.count { g = 0; s += 1; continue }
            let group = section.groups[g]
            if e + 1 >= group.exercises.count { e = 0; g += 1; continue }
            e += 1
            let exercise = group.exercises[e]
            if exercise.sets.isEmpty { continue }
            if exercise.movementDisplayName != currentName {
                return exercise.movementDisplayName
            }
        }
        return nil
    }

    // MARK: - Timers

    var elapsedSeconds: Int {
        guard let start = startedAt else { return 0 }
        let stop = endedAt ?? Date()
        return Int(stop.timeIntervalSince(start))
    }

    var exerciseElapsedSeconds: Int {
        guard let start = exerciseStartedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start)))
    }

    var totalVolumeKg: Double {
        setLogs.reduce(0) { acc, log in
            guard log.outcome == .completed,
                  let reps = log.actualReps, let kg = log.actualWeightKg
            else { return acc }
            return acc + Double(reps) * kg
        }
    }

    // MARK: - Wire payload

    func makePayload() -> WorkoutSessionPayload? {
        guard let trackCode, let day, let startedAt else { return nil }
        return WorkoutSessionPayload(
            clientSessionId: sessionId,
            trackCode: trackCode,
            scheduledOn: day.scheduledOn,
            dayId: nil,
            startedAt: startedAt,
            endedAt: endedAt,
            totalElapsedSeconds: elapsedSeconds,
            status: "completed",
            notes: notes.isEmpty ? nil : notes,
            weightUnit: weightUnit.wireValue,
            setLogs: setLogs.map { log in
                WorkoutSessionPayload.SetLogPayload(
                    sectionPosition: log.setId.section,
                    groupPosition: log.setId.group,
                    exercisePosition: log.setId.exercise,
                    setPosition: log.setId.set,
                    perSide: nil,
                    outcome: log.outcome.rawValue,
                    actualReps: log.actualReps,
                    actualWeightKg: log.actualWeightKg,
                    actualRpe: log.actualRpe,
                    restTakenSeconds: log.restTakenSeconds,
                    completedAt: log.completedAt
                )
            },
            groupScores: []
        )
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                self.tickCounter &+= 1
                if let end = self.restEndsAt, end <= Date() {
                    self.restEndsAt = nil
                }
            }
        }
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }
}

// MARK: - Value types

struct SetId: Hashable, Sendable {
    let section: Int
    let group: Int
    let exercise: Int
    let set: Int
}

struct LoggedSet: Identifiable, Hashable, Sendable {
    let id: UUID
    let setId: SetId
    let outcome: Outcome
    let actualReps: Int?
    let actualWeightKg: Double?
    let actualRpe: Double?
    let restTakenSeconds: Int?
    let completedAt: Date

    enum Outcome: String, Hashable, Sendable {
        case completed, skipped, partial
    }
}

enum WeightUnit: Sendable {
    case kg
    case lb

    var wireValue: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }
}
