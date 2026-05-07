import Foundation

/// Codable payloads exchanged between watch and iPhone over WatchConnectivity
/// to keep an iOS Live Activity in sync with a session running on either
/// device. ActivityKit isn't imported here — this module compiles for
/// watchOS too, where ActivityKit is unavailable. The iOS side maps these
/// payloads onto `WorkoutActivityAttributes.ContentState`.
public enum WatchActivityRelay: Codable, Sendable {
    case start(StartPayload)
    case update(UpdatePayload)
    /// `pausedAt == nil` means resume.
    case pause(sessionId: UUID, pausedAt: Date?)
    case end(EndPayload)
    case abandon(sessionId: UUID)
    /// iPhone → Watch: a Lock-Screen / Dynamic Island button was tapped
    /// while the session is owned by the watch. Watch acts on it as if
    /// the user had pressed the button on-device.
    case intentDispatch(IntentDispatchPayload)

    public struct StartPayload: Codable, Sendable {
        public let workoutTitle: String
        public let trackDisplayName: String
        public let sessionId: UUID
        public let startedAt: Date
        public let initialState: UpdatePayload

        public init(
            workoutTitle: String,
            trackDisplayName: String,
            sessionId: UUID,
            startedAt: Date,
            initialState: UpdatePayload
        ) {
            self.workoutTitle = workoutTitle
            self.trackDisplayName = trackDisplayName
            self.sessionId = sessionId
            self.startedAt = startedAt
            self.initialState = initialState
        }
    }

    public struct UpdatePayload: Codable, Sendable, Hashable {
        public var sessionId: UUID
        public var timerStart: Date
        public var pausedAt: Date?
        public var currentExerciseName: String
        public var setProgressLabel: String
        public var groupModeLabel: String?
        public var restEndsAt: Date?
        public var restPlannedSeconds: Int?
        public var setsCompleted: Int
        public var setsTotal: Int

        public init(
            sessionId: UUID,
            timerStart: Date,
            pausedAt: Date?,
            currentExerciseName: String,
            setProgressLabel: String,
            groupModeLabel: String?,
            restEndsAt: Date?,
            restPlannedSeconds: Int?,
            setsCompleted: Int,
            setsTotal: Int
        ) {
            self.sessionId = sessionId
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

    public struct EndPayload: Codable, Sendable {
        public let sessionId: UUID
        public let finalState: UpdatePayload

        public init(sessionId: UUID, finalState: UpdatePayload) {
            self.sessionId = sessionId
            self.finalState = finalState
        }
    }

    public enum IntentKind: String, Codable, Sendable {
        case togglePause
        case logSet
    }

    public struct IntentDispatchPayload: Codable, Sendable {
        public let sessionId: UUID
        public let kind: IntentKind

        public init(sessionId: UUID, kind: IntentKind) {
            self.sessionId = sessionId
            self.kind = kind
        }
    }
}

/// Helper for building an `UpdatePayload` from the engine's source of truth.
/// Lives here (next to the payload) so iOS and watch produce identical
/// payloads from identical sessions.
@MainActor
public enum WatchActivityRelayBuilder {
    public static func makeUpdate(from session: WorkoutSession) -> WatchActivityRelay.UpdatePayload {
        let started = session.startedAt ?? Date()
        let timerStart = started.addingTimeInterval(session.pausedAccumulatedSeconds)
        let restEndsAt: Date? = session.restAfter.map { rest in
            rest.startedAt.addingTimeInterval(TimeInterval(rest.plannedSeconds))
        }
        return WatchActivityRelay.UpdatePayload(
            sessionId: session.sessionId,
            timerStart: timerStart,
            pausedAt: session.pauseStartedAt,
            currentExerciseName: CursorDescriptors.currentExerciseName(cursor: session.cursor, in: session.day),
            setProgressLabel: CursorDescriptors.setProgressLabel(cursor: session.cursor, in: session.day),
            groupModeLabel: CursorDescriptors.groupModeLabel(activeBlock: session.activeBlock),
            restEndsAt: restEndsAt,
            restPlannedSeconds: session.restAfter?.plannedSeconds,
            setsCompleted: CursorDescriptors.setsCompleted(setLog: session.setLog),
            setsTotal: CursorDescriptors.totalSets(in: session.day)
        )
    }

    public static func makeStart(from session: WorkoutSession) -> WatchActivityRelay.StartPayload {
        WatchActivityRelay.StartPayload(
            workoutTitle: session.day.displayName,
            trackDisplayName: session.trackDisplayName ?? session.trackCode,
            sessionId: session.sessionId,
            startedAt: session.startedAt ?? Date(),
            initialState: makeUpdate(from: session)
        )
    }
}
