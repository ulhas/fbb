import ActivityKit
import Foundation

/// Identity + dynamic content for the workout Live Activity. **This file
/// must be in the target membership of both the `byow` app target and the
/// `byowWorkoutWidget` extension target** — both sides need the same type
/// to identify the activity.
public struct WorkoutActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    /// `ParsedDay.displayName` (e.g., "Day 3 — Lift").
    public let workoutTitle: String
    /// Track display name (e.g., "Build", "Pump").
    public let trackDisplayName: String
    public let sessionId: UUID
    public let startedAt: Date

    public init(
        workoutTitle: String,
        trackDisplayName: String,
        sessionId: UUID,
        startedAt: Date
    ) {
        self.workoutTitle = workoutTitle
        self.trackDisplayName = trackDisplayName
        self.sessionId = sessionId
        self.startedAt = startedAt
    }

    public struct State: Codable, Hashable {
        /// Effective wall-clock anchor for the elapsed-time clock —
        /// equals `startedAt + pausedAccumulatedSeconds`. Used as the
        /// lower bound of `Text(timerInterval:pauseTime:)` so the label
        /// auto-ticks without pushing per-second updates.
        public var timerStart: Date
        /// When non-nil, freezes `Text(timerInterval:pauseTime:)`.
        public var pausedAt: Date?

        public var currentExerciseName: String
        public var setProgressLabel: String
        public var groupModeLabel: String?

        public var restEndsAt: Date?
        public var restPlannedSeconds: Int?

        public var setsCompleted: Int
        public var setsTotal: Int

        public init(
            timerStart: Date,
            pausedAt: Date? = nil,
            currentExerciseName: String,
            setProgressLabel: String,
            groupModeLabel: String? = nil,
            restEndsAt: Date? = nil,
            restPlannedSeconds: Int? = nil,
            setsCompleted: Int,
            setsTotal: Int
        ) {
            self.timerStart = timerStart
            self.pausedAt = pausedAt
            self.currentExerciseName = currentExerciseName
            self.setProgressLabel = setProgressLabel
            self.groupModeLabel = groupModeLabel
            self.restEndsAt = restEndsAt
            self.restPlannedSeconds = restPlannedSeconds
            self.setsCompleted = setsCompleted
            self.setsTotal = setsTotal
        }
    }
}
