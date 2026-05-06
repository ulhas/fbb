import Foundation

// Mirrors packages/types/src/index.ts TrainingWeek* shapes. Snake_case via
// JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase.

struct ParsedMicrocycleHint: Codable, Hashable, Sendable {
    let kind: MicrocycleKind
    let startsOn: String
    let endsOn: String
    let mesocyclePositionHint: Int?
    let weekPosition: Int?
}

struct TrainingWeekSummaryRow: Codable, Hashable, Sendable, Identifiable {
    var id: String { weekStartsOn }

    let weekStartsOn: String
    let weekEndsOn: String
    let trackCount: Int
    let dayCount: Int
    let parsedDayCount: Int
    let underparsedDayCount: Int
    let weekPosition: Int?
    let microcycleKind: String?
    let lastPersistedAt: String

    static let placeholder = TrainingWeekSummaryRow(
        weekStartsOn: "2026-01-05",
        weekEndsOn: "2026-01-11",
        trackCount: 4,
        dayCount: 28,
        parsedDayCount: 28,
        underparsedDayCount: 0,
        weekPosition: 3,
        microcycleKind: "standard",
        lastPersistedAt: "2026-01-04T12:00:00Z"
    )
}

struct TrainingWeekDayMetaRow: Codable, Hashable, Sendable, Identifiable {
    var id: String { scheduledOn }

    let scheduledOn: String
    let position: Int
    let displayName: String
    let kind: DayKind
    let isOptional: Bool
    let sectionCount: Int
    let exerciseCount: Int

    static let placeholder = TrainingWeekDayMetaRow(
        scheduledOn: "2026-01-05",
        position: 1,
        displayName: "Lower Day 1",
        kind: .workout,
        isOptional: false,
        sectionCount: 3,
        exerciseCount: 8
    )
}

struct TrainingWeekTrackIndexRow: Codable, Hashable, Sendable, Identifiable {
    var id: String { trackCode }

    let trackCode: String
    let family: TrackFamily
    let cadence: TrackCadence?
    let displayName: String
    let microcycle: ParsedMicrocycleHint
    let days: [TrainingWeekDayMetaRow]

    static let placeholder = TrainingWeekTrackIndexRow(
        trackCode: "pump_lift_4x",
        family: .pumpLift,
        cadence: .x4,
        displayName: "PUMP LIFT 4x",
        microcycle: ParsedMicrocycleHint(
            kind: .standard,
            startsOn: "2026-01-05",
            endsOn: "2026-01-11",
            mesocyclePositionHint: 2,
            weekPosition: 3
        ),
        days: (1...7).map { i in
            TrainingWeekDayMetaRow(
                scheduledOn: "2026-01-0\(4 + i)",
                position: i,
                displayName: "Day \(i)",
                kind: i == 4 ? .rest : .workout,
                isOptional: false,
                sectionCount: 3,
                exerciseCount: 8
            )
        }
    )
}

struct TrainingWeekDetailRow: Codable, Hashable, Sendable {
    let weekStartsOn: String
    let weekEndsOn: String
    let tracks: [TrainingWeekTrackIndexRow]
    let lastPersistedAt: String
    let lastUploadJobId: String?
}
