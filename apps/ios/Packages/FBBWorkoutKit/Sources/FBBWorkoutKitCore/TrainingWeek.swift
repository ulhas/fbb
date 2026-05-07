import Foundation

// Mirrors packages/types/src/index.ts TrainingWeek* shapes. Snake_case via
// JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase.

public struct ParsedMicrocycleHint: Codable, Hashable, Sendable {
    public let kind: MicrocycleKind
    public let startsOn: String
    public let endsOn: String
    public let mesocyclePositionHint: Int?
    public let weekPosition: Int?
}

public struct TrainingWeekSummaryRow: Codable, Hashable, Sendable, Identifiable {
    public var id: String { weekStartsOn }

    public let weekStartsOn: String
    public let weekEndsOn: String
    public let trackCount: Int
    public let dayCount: Int
    public let parsedDayCount: Int
    public let underparsedDayCount: Int
    public let weekPosition: Int?
    public let microcycleKind: String?
    public let lastPersistedAt: String

    public static let placeholder = TrainingWeekSummaryRow(
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

public struct TrainingWeekDayMetaRow: Codable, Hashable, Sendable, Identifiable {
    public var id: String { scheduledOn }

    public let scheduledOn: String
    public let position: Int
    public let displayName: String
    public let kind: DayKind
    public let isOptional: Bool
    public let sectionCount: Int
    public let exerciseCount: Int

    public static let placeholder = TrainingWeekDayMetaRow(
        scheduledOn: "2026-01-05",
        position: 1,
        displayName: "Lower Day 1",
        kind: .workout,
        isOptional: false,
        sectionCount: 3,
        exerciseCount: 8
    )
}

public struct TrainingWeekTrackIndexRow: Codable, Hashable, Sendable, Identifiable {
    public var id: String { trackCode }

    public let trackCode: String
    public let family: TrackFamily
    public let cadence: TrackCadence?
    public let displayName: String
    public let microcycle: ParsedMicrocycleHint
    public let days: [TrainingWeekDayMetaRow]

    public static let placeholder = TrainingWeekTrackIndexRow(
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

public struct TrainingWeekDetailRow: Codable, Hashable, Sendable {
    public let weekStartsOn: String
    public let weekEndsOn: String
    public let tracks: [TrainingWeekTrackIndexRow]
    public let lastPersistedAt: String
    public let lastUploadJobId: String?
}
