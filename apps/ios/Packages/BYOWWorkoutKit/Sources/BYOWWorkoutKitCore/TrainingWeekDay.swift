import Foundation

// Mirrors packages/types/src/index.ts (TrainingWeekDayCellRow, TrainingWeekDayDetailRow).

public struct TrainingWeekDayCellRow: Codable, Hashable, Sendable, Identifiable {
    public var id: String { track.trackCode }
    public let track: TrackHeader
    public let day: ParsedDay

    public struct TrackHeader: Codable, Hashable, Sendable {
        public let trackCode: String
        public let family: TrackFamily
        public let cadence: TrackCadence?
        public let displayName: String
        public let microcycle: ParsedMicrocycleHint
    }
}

public struct TrainingWeekDayDetailRow: Codable, Hashable, Sendable {
    public let scheduledOn: String
    public let cells: [TrainingWeekDayCellRow]
}
