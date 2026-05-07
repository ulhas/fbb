import Foundation

// Wire format for POST /workouts/sessions and the response. Snake_case is
// converted via JSONEncoder.keyEncodingStrategy = .convertToSnakeCase, so
// the iOS struct is camelCase. This struct round-trips to and from the
// server, so the same DTO is used to read history (GET /:id).

public struct WorkoutSessionPayload: Codable, Hashable, Sendable {
    public let clientSessionId: UUID
    public let trackCode: String
    public let scheduledOn: String
    public let dayId: String?
    public let startedAt: Date
    public let endedAt: Date?
    public let totalElapsedSeconds: Int
    public let status: String         // "completed" | "abandoned"
    public let notes: String?
    public let weightUnit: String     // "kg" | "lb"
    public let setLogs: [SetLogPayload]
    public let groupScores: [GroupScorePayload]

    public init(
        clientSessionId: UUID,
        trackCode: String,
        scheduledOn: String,
        dayId: String?,
        startedAt: Date,
        endedAt: Date?,
        totalElapsedSeconds: Int,
        status: String,
        notes: String?,
        weightUnit: String,
        setLogs: [SetLogPayload],
        groupScores: [GroupScorePayload]
    ) {
        self.clientSessionId = clientSessionId
        self.trackCode = trackCode
        self.scheduledOn = scheduledOn
        self.dayId = dayId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalElapsedSeconds = totalElapsedSeconds
        self.status = status
        self.notes = notes
        self.weightUnit = weightUnit
        self.setLogs = setLogs
        self.groupScores = groupScores
    }

    public struct SetLogPayload: Codable, Hashable, Sendable {
        public let sectionPosition: Int
        public let groupPosition: Int
        public let exercisePosition: Int
        public let setPosition: Int
        public let perSide: String?
        public let outcome: String
        public let actualReps: Int?
        public let actualWeightKg: Double?
        public let actualRpe: Double?
        public let restTakenSeconds: Int?
        public let completedAt: Date

        public init(
            sectionPosition: Int,
            groupPosition: Int,
            exercisePosition: Int,
            setPosition: Int,
            perSide: String?,
            outcome: String,
            actualReps: Int?,
            actualWeightKg: Double?,
            actualRpe: Double?,
            restTakenSeconds: Int?,
            completedAt: Date
        ) {
            self.sectionPosition = sectionPosition
            self.groupPosition = groupPosition
            self.exercisePosition = exercisePosition
            self.setPosition = setPosition
            self.perSide = perSide
            self.outcome = outcome
            self.actualReps = actualReps
            self.actualWeightKg = actualWeightKg
            self.actualRpe = actualRpe
            self.restTakenSeconds = restTakenSeconds
            self.completedAt = completedAt
        }
    }

    public struct GroupScorePayload: Codable, Hashable, Sendable {
        public let sectionPosition: Int
        public let groupPosition: Int
        public let prescriptionMode: String
        public let rounds: Int?
        public let partialReps: Int?
        public let finishSeconds: Int?
        public let totalReps: Int?

        public init(
            sectionPosition: Int,
            groupPosition: Int,
            prescriptionMode: String,
            rounds: Int?,
            partialReps: Int?,
            finishSeconds: Int?,
            totalReps: Int?
        ) {
            self.sectionPosition = sectionPosition
            self.groupPosition = groupPosition
            self.prescriptionMode = prescriptionMode
            self.rounds = rounds
            self.partialReps = partialReps
            self.finishSeconds = finishSeconds
            self.totalReps = totalReps
        }
    }
}
