import Foundation

// Mirrors packages/types/src/index.ts (ParsedSet, ParsedExercise, ParsedGroup,
// ParsedSection, ParsedCoachingNote, ParsedDay). Snake_case keys are mapped via
// JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase.

public struct DropSetDescriptor: Codable, Hashable, Sendable {
    public let drops: Int
    public let reducePct: [Double]?
    public let notes: String?
}

public struct PyramidStep: Codable, Hashable, Sendable {
    public let durationSeconds: Int
    public let intensityPct: Double?
    public let notes: String?
}

public struct ParsedSet: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { position }

    public let position: Int
    public let setKind: String
    public let repsKind: String
    public let repsMin: Int?
    public let repsMax: Int?
    public let repsText: String?
    public let durationSecondsMin: Int?
    public let durationSecondsMax: Int?
    public let perSide: Bool
    public let tempo: String?
    public let rpeMin: Double?
    public let rpeMax: Double?
    public let rpeText: String?
    public let weightRef: WeightRef
    public let restAfterSecondsMin: Int?
    public let restAfterSecondsMax: Int?
    public let restAfterText: String?
    public let hasDropSet: Bool
    public let dropSetDescriptor: DropSetDescriptor?
    public let notes: String?
}

public struct ParsedExercise: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { position }

    public let position: Int
    public let movementDisplayName: String
    public let alternateOfPosition: Int?
    public let chainedIntoNext: Bool
    public let restAfterSecondsMin: Int?
    public let restAfterSecondsMax: Int?
    public let restAfterText: String?
    public let isUnilateral: Bool
    public let perSideStarts: String?
    public let notes: String?
    public let sets: [ParsedSet]
}

public struct ParsedGroup: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { position }

    public let position: Int
    public let prescriptionMode: String
    public let roundCountMin: Int?
    public let roundCountMax: Int?
    public let intervalSeconds: Int?
    public let capSeconds: Int?
    public let restBetweenRoundsSecondsMin: Int?
    public let restBetweenRoundsSecondsMax: Int?
    public let restBetweenRoundsText: String?
    public let loadingNote: String?
    public let effortNote: String?
    public let shortOnTimeRemove: Bool
    public let scoring: String?
    public let intervalPyramidSteps: [PyramidStep]?
    public let progressionText: String?
    public let exercises: [ParsedExercise]
}

public struct ParsedSection: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { position }

    public let position: Int
    public let letter: String
    public let kind: String
    public let displayName: String
    public let targetDurationMin: Int?
    public let targetDurationMax: Int?
    public let prescriptionMode: String
    public let dailyFocusNote: String?
    public let effortNote: String?
    public let shortOnTimeDirective: String?
    public let groups: [ParsedGroup]
}

public struct ParsedCoachingNote: Codable, Hashable, Sendable {
    public let kind: String
    public let title: String?
    public let bodyMarkdown: String
}

public struct ParsedDay: Codable, Hashable, Sendable, Identifiable {
    public var id: String { scheduledOn }

    public let scheduledOn: String       // YYYY-MM-DD
    public let position: Int
    public let displayName: String
    public let kind: DayKind
    public let isOptional: Bool
    public let weekPosition: Int?
    public let dayPosition: Int?
    public let rawText: String
    public let cmsSourceId: String
    public let sections: [ParsedSection]
    public let coachingNotes: [ParsedCoachingNote]

    public var totalExercises: Int {
        sections.reduce(0) { $0 + $1.groups.reduce(0) { $0 + $1.exercises.count } }
    }
}
