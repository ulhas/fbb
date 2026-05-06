import Foundation

// Mirrors packages/types/src/index.ts (TrainingWeekDayCellRow, TrainingWeekDayDetailRow).

struct TrainingWeekDayCellRow: Codable, Hashable, Sendable, Identifiable {
    var id: String { track.trackCode }
    let track: TrackHeader
    let day: ParsedDay

    struct TrackHeader: Codable, Hashable, Sendable {
        let trackCode: String
        let family: TrackFamily
        let cadence: TrackCadence?
        let displayName: String
        let microcycle: ParsedMicrocycleHint
    }
}

struct TrainingWeekDayDetailRow: Codable, Hashable, Sendable {
    let scheduledOn: String
    let cells: [TrainingWeekDayCellRow]
}
