import Foundation

// Mirrors packages/types/src/index.ts (ParsedSet, ParsedExercise, ParsedGroup,
// ParsedSection, ParsedCoachingNote, ParsedDay). Snake_case keys are mapped via
// JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase.

struct DropSetDescriptor: Codable, Hashable, Sendable {
    let drops: Int
    let reducePct: [Double]?
    let notes: String?
}

struct PyramidStep: Codable, Hashable, Sendable {
    let durationSeconds: Int
    let intensityPct: Double?
    let notes: String?
}

struct ParsedSet: Codable, Hashable, Sendable, Identifiable {
    var id: Int { position }

    let position: Int
    let setKind: String
    let repsKind: String
    let repsMin: Int?
    let repsMax: Int?
    let repsText: String?
    let durationSecondsMin: Int?
    let durationSecondsMax: Int?
    let perSide: Bool
    let tempo: String?
    let rpeMin: Double?
    let rpeMax: Double?
    let rpeText: String?
    let weightRef: WeightRef
    let restAfterSecondsMin: Int?
    let restAfterSecondsMax: Int?
    let restAfterText: String?
    let hasDropSet: Bool
    let dropSetDescriptor: DropSetDescriptor?
    let notes: String?
}

struct ParsedExercise: Codable, Hashable, Sendable, Identifiable {
    var id: Int { position }

    let position: Int
    let movementDisplayName: String
    let alternateOfPosition: Int?
    let chainedIntoNext: Bool
    let restAfterSecondsMin: Int?
    let restAfterSecondsMax: Int?
    let restAfterText: String?
    let isUnilateral: Bool
    let perSideStarts: String?
    let notes: String?
    let sets: [ParsedSet]
}

struct ParsedGroup: Codable, Hashable, Sendable, Identifiable {
    var id: Int { position }

    let position: Int
    let prescriptionMode: String
    let roundCountMin: Int?
    let roundCountMax: Int?
    let intervalSeconds: Int?
    let capSeconds: Int?
    let restBetweenRoundsSecondsMin: Int?
    let restBetweenRoundsSecondsMax: Int?
    let restBetweenRoundsText: String?
    let loadingNote: String?
    let effortNote: String?
    let shortOnTimeRemove: Bool
    let scoring: String?
    let intervalPyramidSteps: [PyramidStep]?
    let progressionText: String?
    let exercises: [ParsedExercise]
}

struct ParsedSection: Codable, Hashable, Sendable, Identifiable {
    var id: Int { position }

    let position: Int
    let letter: String
    let kind: String
    let displayName: String
    let targetDurationMin: Int?
    let targetDurationMax: Int?
    let prescriptionMode: String
    let dailyFocusNote: String?
    let effortNote: String?
    let shortOnTimeDirective: String?
    let groups: [ParsedGroup]
}

struct ParsedCoachingNote: Codable, Hashable, Sendable {
    let kind: String
    let title: String?
    let bodyMarkdown: String
}

struct ParsedDay: Codable, Hashable, Sendable, Identifiable {
    var id: String { scheduledOn }

    let scheduledOn: String       // YYYY-MM-DD
    let position: Int
    let displayName: String
    let kind: DayKind
    let isOptional: Bool
    let weekPosition: Int?
    let dayPosition: Int?
    let rawText: String
    let cmsSourceId: String
    let sections: [ParsedSection]
    let coachingNotes: [ParsedCoachingNote]

    var totalExercises: Int {
        sections.reduce(0) { $0 + $1.groups.reduce(0) { $0 + $1.exercises.count } }
    }
}
