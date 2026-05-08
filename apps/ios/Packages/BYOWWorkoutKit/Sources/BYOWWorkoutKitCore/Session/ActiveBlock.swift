import Foundation

// Mode-specific live state for the group the cursor currently sits in.
// Computed from the immutable plan + the cursor + the wall clock; the
// engine recomputes this on each tick (and on cursor moves) so it never
// has to be hand-maintained. Codable so persistence can resume the right
// block on relaunch.
public enum ActiveBlock: Codable, Hashable, Sendable {
    /// User-paced (straight_sets, rounds, free). The footer shows total
    /// elapsed and rest (if any); there is no group countdown.
    case none(GroupId)
    /// EMOM family + every_x_minutes. Counts down from `intervalSeconds`,
    /// flips to a new round at each tick boundary.
    case interval(IntervalState)
    /// AMRAP, for_time, density. Counts down from `capSeconds`.
    case capCountdown(CapState)
    /// Tabata: fixed 20s/10s × 8 rounds.
    case tabata(TabataState)
    /// interval_pyramid: auto-advancing scripted countdowns.
    case pyramid(PyramidState)
    /// continuous_effort: open-ended stopwatch.
    case stopwatch(StopwatchState)

    public var groupId: GroupId {
        switch self {
        case .none(let g): return g
        case .interval(let s): return s.groupId
        case .capCountdown(let s): return s.groupId
        case .tabata(let s): return s.groupId
        case .pyramid(let s): return s.groupId
        case .stopwatch(let s): return s.groupId
        }
    }

    /// Push every wall-clock anchor inside this block forward by
    /// `seconds`. Used on resume after a pause so the timer thinks no
    /// time passed during the pause window.
    public func shiftedForward(by seconds: TimeInterval) -> ActiveBlock {
        let bump: (Date) -> Date = { $0.addingTimeInterval(seconds) }
        switch self {
        case .none: return self
        case .interval(let s):
            return .interval(IntervalState(
                groupId: s.groupId,
                intervalSeconds: s.intervalSeconds,
                totalRounds: s.totalRounds,
                startedAt: bump(s.startedAt)
            ))
        case .capCountdown(let s):
            return .capCountdown(CapState(
                groupId: s.groupId,
                capSeconds: s.capSeconds,
                startedAt: bump(s.startedAt),
                userRoundsCompleted: s.userRoundsCompleted,
                userPartialReps: s.userPartialReps
            ))
        case .tabata(let s):
            return .tabata(TabataState(
                groupId: s.groupId,
                startedAt: bump(s.startedAt),
                totalRounds: s.totalRounds,
                workSeconds: s.workSeconds,
                restSeconds: s.restSeconds
            ))
        case .pyramid(let s):
            return .pyramid(PyramidState(
                groupId: s.groupId,
                steps: s.steps,
                startedAt: bump(s.startedAt)
            ))
        case .stopwatch(let s):
            return .stopwatch(StopwatchState(
                groupId: s.groupId,
                startedAt: bump(s.startedAt)
            ))
        }
    }
}

public struct IntervalState: Codable, Hashable, Sendable {
    public let groupId: GroupId
    public let intervalSeconds: Int
    public let totalRounds: Int
    public let startedAt: Date

    public func roundIndex(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return elapsed / max(1, intervalSeconds)
    }

    public func roundElapsedSeconds(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return elapsed % max(1, intervalSeconds)
    }

    public func roundRemainingSeconds(now: Date) -> Int {
        intervalSeconds - roundElapsedSeconds(now: now)
    }

    public func isComplete(now: Date) -> Bool {
        roundIndex(now: now) >= totalRounds
    }
}

public struct CapState: Codable, Hashable, Sendable {
    public let groupId: GroupId
    public let capSeconds: Int
    public let startedAt: Date
    /// User-controlled — incremented when the user taps "+1 round". Lives
    /// here so it persists across tick recomputations.
    public var userRoundsCompleted: Int
    public var userPartialReps: Int

    public func remainingSeconds(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return capSeconds - elapsed
    }

    public func elapsedSeconds(now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt)))
    }

    public func isExpired(now: Date) -> Bool {
        remainingSeconds(now: now) <= 0
    }
}

public struct TabataState: Codable, Hashable, Sendable {
    public enum SubPhase: String, Codable, Sendable, Hashable { case work, rest }

    public let groupId: GroupId
    public let startedAt: Date
    public let totalRounds: Int       // typically 8
    public let workSeconds: Int       // typically 20
    public let restSeconds: Int       // typically 10

    public var cycleSeconds: Int { workSeconds + restSeconds }

    public func roundIndex(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return elapsed / cycleSeconds
    }

    public func subPhase(now: Date) -> SubPhase {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        let inCycle = elapsed % cycleSeconds
        return inCycle < workSeconds ? .work : .rest
    }

    public func subPhaseRemainingSeconds(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        let inCycle = elapsed % cycleSeconds
        return subPhase(now: now) == .work
            ? workSeconds - inCycle
            : cycleSeconds - inCycle
    }

    public func isComplete(now: Date) -> Bool {
        roundIndex(now: now) >= totalRounds
    }
}

public struct PyramidState: Codable, Hashable, Sendable {
    public let groupId: GroupId
    public let steps: [PyramidStep]
    public let startedAt: Date

    public func cumulativeStepEnds(at index: Int) -> Int {
        guard index < steps.count else { return totalSeconds }
        return steps.prefix(index + 1).reduce(0) { $0 + $1.durationSeconds }
    }

    public var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.durationSeconds }
    }

    public func currentStepIndex(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        var running = 0
        for (idx, step) in steps.enumerated() {
            running += step.durationSeconds
            if elapsed < running { return idx }
        }
        return steps.count // past the end
    }

    public func stepRemainingSeconds(now: Date) -> Int {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        let idx = currentStepIndex(now: now)
        guard idx < steps.count else { return 0 }
        let stepStart = idx == 0 ? 0 : cumulativeStepEnds(at: idx - 1)
        let inStep = elapsed - stepStart
        return steps[idx].durationSeconds - inStep
    }

    public func isComplete(now: Date) -> Bool {
        currentStepIndex(now: now) >= steps.count
    }
}

public struct StopwatchState: Codable, Hashable, Sendable {
    public let groupId: GroupId
    public let startedAt: Date

    public func elapsedSeconds(now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt)))
    }
}

// Build the right ActiveBlock for whichever group the cursor currently
// sits in. Called when the cursor moves into a new group, or on engine
// start. The reducer takes the immutable plan + a "block start time"
// anchor (usually `now`) and produces the matching state.
public enum ActiveBlockReducer {
    public static func make(
        for group: ParsedGroup,
        in section: ParsedSection,
        startedAt: Date
    ) -> ActiveBlock {
        let gid = GroupId(section: section.position, group: group.position)

        switch group.prescriptionMode {
        case "emom", "e2mom", "e3mom", "every_x_minutes":
            let interval = group.intervalSeconds
                ?? defaultInterval(for: group.prescriptionMode)
            let rounds = group.roundCountMax
                ?? group.roundCountMin
                ?? defaultRounds(for: group.prescriptionMode, capSeconds: group.capSeconds, interval: interval)
            return .interval(IntervalState(
                groupId: gid,
                intervalSeconds: interval,
                totalRounds: rounds,
                startedAt: startedAt
            ))

        case "amrap", "for_time", "density":
            let cap = group.capSeconds ?? defaultCap(for: group.prescriptionMode)
            return .capCountdown(CapState(
                groupId: gid,
                capSeconds: cap,
                startedAt: startedAt,
                userRoundsCompleted: 0,
                userPartialReps: 0
            ))

        case "tabata":
            return .tabata(TabataState(
                groupId: gid,
                startedAt: startedAt,
                totalRounds: group.roundCountMax ?? group.roundCountMin ?? 8,
                workSeconds: 20,
                restSeconds: 10
            ))

        case "interval_pyramid":
            let steps = group.intervalPyramidSteps ?? []
            return .pyramid(PyramidState(
                groupId: gid,
                steps: steps,
                startedAt: startedAt
            ))

        case "continuous_effort":
            return .stopwatch(StopwatchState(groupId: gid, startedAt: startedAt))

        default:
            // straight_sets, rounds, free, and unknown values fall through
            // to the user-paced "no group timer" case.
            return .none(gid)
        }
    }

    private static func defaultInterval(for mode: String) -> Int {
        switch mode {
        case "emom":  return 60
        case "e2mom": return 120
        case "e3mom": return 180
        default:      return 60
        }
    }

    private static func defaultRounds(
        for mode: String,
        capSeconds: Int?,
        interval: Int
    ) -> Int {
        if let cap = capSeconds, cap > 0, interval > 0 {
            return cap / interval
        }
        return 10
    }

    private static func defaultCap(for mode: String) -> Int {
        switch mode {
        case "amrap":    return 600  // 10min default
        case "for_time": return 1200 // 20min soft cap
        case "density":  return 600
        default:         return 600
        }
    }
}
