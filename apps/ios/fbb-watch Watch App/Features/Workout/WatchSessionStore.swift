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
    enum Phase: Sendable {
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
    var sectionIdx = 0
    var groupIdx = 0
    var exerciseIdx = 0
    var setIdx = 0

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
        self.sectionIdx = 0
        self.groupIdx = 0
        self.exerciseIdx = 0
        self.setIdx = 0
        self.setLogs = []
        self.notes = ""
        self.weightUnit = .kg
        self.restEndsAt = nil
        self.phase = .running
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

    func advanceCursor() {
        guard let day else { return }
        var s = sectionIdx, g = groupIdx, e = exerciseIdx, set = setIdx + 1

        // Walk forward, hopping out of exercises/groups/sections when their
        // children are exhausted.
        while s < day.sections.count {
            let section = day.sections[s]
            if g >= section.groups.count { g = 0; s += 1; continue }
            let group = section.groups[g]
            if e >= group.exercises.count { e = 0; g += 1; continue }
            let exercise = group.exercises[e]
            if set >= exercise.sets.count { set = 0; e += 1; continue }
            sectionIdx = s; groupIdx = g; exerciseIdx = e; setIdx = set
            return
        }
        // No more sets — auto-end.
        end()
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

    var elapsedSeconds: Int {
        guard let start = startedAt else { return 0 }
        let stop = endedAt ?? Date()
        return Int(stop.timeIntervalSince(start))
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
