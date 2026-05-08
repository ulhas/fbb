import Foundation

// MARK: - Top-level overview

/// Everything the Stats screen renders for one viewer in one session.
/// Phase 1 ships from `MockStatsSource`; Phase 2 will be `LiveStatsSource`
/// over `/stats/overview`.
struct StatsOverview: Sendable {
    let microcycle: MicrocycleContext
    let hero: HeroInsight
    let kpis: [KPIValue]
    let tracks: [TrackProgression]
    let balance: [MovementBalanceSlice]
    let trend: [VolumePoint]
    let recovery: RecoverySnapshot
    let prs: [PRRecord]
    let heatmap: [AdherenceCell]
    let insights: [Insight]
}

// MARK: - Recovery & Health (Apple Health surface)

/// Mock now, real later. Phase 2 will populate from HealthKit reads
/// (`HKQuantityType.quantityType(forIdentifier: .stepCount)` etc.) into
/// the backend `body_metrics` table whose `source` column already accepts
/// `healthkit | health_connect | whoop | oura | garmin`.
struct RecoverySnapshot: Sendable {
    let sleep: HealthMetric
    let hrv: HealthMetric
    let restingHR: HealthMetric
    let steps: HealthMetric
    let weight: BodyWeightTrend
    let lastSyncedAt: Date

    var lastSyncedLabel: String {
        let interval = Date().timeIntervalSince(lastSyncedAt)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }
}

struct HealthMetric: Sendable, Identifiable {
    let id: UUID
    let label: String
    let value: String
    let unit: String?
    let symbol: String
    let spark: [Double]
    let deltaLabel: String?
    let state: KPIValue.State

    init(
        label: String,
        value: String,
        unit: String? = nil,
        symbol: String,
        spark: [Double],
        deltaLabel: String? = nil,
        state: KPIValue.State
    ) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.unit = unit
        self.symbol = symbol
        self.spark = spark
        self.deltaLabel = deltaLabel
        self.state = state
    }
}

struct BodyWeightTrend: Sendable {
    /// Daily samples, oldest → newest. ISO date strings.
    let points: [WeightPoint]
    let trendLabel: String

    var latestLb: Double? { points.last?.weightLb }
}

struct WeightPoint: Sendable, Identifiable {
    var id: String { date }
    let date: String
    let weightLb: Double
}

// MARK: - Header context

struct MicrocycleContext: Sendable, Hashable {
    let kind: MicrocycleKind
    let intent: MesocycleIntent?
    let weekPosition: Int?
    let weekTotal: Int?

    var summary: String {
        switch kind {
        case .bridgeWeek, .orphanBridge:
            return "Bridge Week"
        case .deload:
            return "Deload"
        case .standard:
            if let intent {
                if let weekPosition, let weekTotal {
                    return "\(intent.displayLabel) · Wk \(weekPosition)/\(weekTotal)"
                }
                return intent.displayLabel
            }
            return "Training"
        }
    }
}

// MARK: - Hero

struct HeroInsight: Sendable, Identifiable {
    let id: UUID
    let body: String
    let signature: String
    let generatedAt: Date

    var freshnessLabel: String {
        let interval = Date().timeIntervalSince(generatedAt)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }
}

// MARK: - KPI strip

struct KPIValue: Sendable, Identifiable {
    enum State: Sendable { case onPlan, lagging, gaining, neutral }

    let id: UUID
    let label: String
    let value: String
    let detail: String?
    let delta: String?
    let state: State
    let symbol: String

    init(
        label: String,
        value: String,
        detail: String? = nil,
        delta: String? = nil,
        state: State,
        symbol: String
    ) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.detail = detail
        self.delta = delta
        self.state = state
        self.symbol = symbol
    }
}

// MARK: - Tracks

struct TrackProgression: Sendable, Identifiable {
    var id: String { trackCode }
    let trackCode: String
    let displayName: String
    let family: TrackFamily
    let intent: MesocycleIntent
    let weekPosition: Int
    let weekTotal: Int
    let sparkline: [Double]
    let topMover: String?
    let isFocused: Bool
}

// MARK: - Movement balance

struct MovementBalanceSlice: Sendable, Identifiable {
    let id: UUID
    let pattern: String
    let sets: Int
    let percent: Double
    let isFlagged: Bool

    init(pattern: String, sets: Int, percent: Double, isFlagged: Bool = false) {
        self.id = UUID()
        self.pattern = pattern
        self.sets = sets
        self.percent = percent
        self.isFlagged = isFlagged
    }
}

// MARK: - Volume trend

struct VolumePoint: Sendable, Identifiable {
    var id: String { weekStartsOn }
    let weekStartsOn: String
    let volumeLb: Double
    let microcycleKind: MicrocycleKind
    let isPRWeek: Bool
}

// MARK: - PR feed

struct PRRecord: Sendable, Identifiable {
    let id: UUID
    let movement: String
    let repMax: Int        // 1RM = 1, 3RM = 3, etc.
    let weightLb: Double
    let achievedOn: String // ISO YYYY-MM-DD
    let deltaLb: Double?

    init(
        movement: String,
        repMax: Int,
        weightLb: Double,
        achievedOn: String,
        deltaLb: Double? = nil
    ) {
        self.id = UUID()
        self.movement = movement
        self.repMax = repMax
        self.weightLb = weightLb
        self.achievedOn = achievedOn
        self.deltaLb = deltaLb
    }

    var repMaxLabel: String { "\(repMax)RM" }
}

// MARK: - Adherence heatmap

struct AdherenceCell: Sendable, Identifiable {
    enum Status: Sendable {
        case missed         // scheduled, not done
        case skipped        // optional, not done
        case completed      // done as prescribed
        case exceeded       // done above prescription
        case rest           // scheduled rest
        case future         // upcoming, not yet
    }

    var id: String { date }
    let date: String  // ISO YYYY-MM-DD
    let status: Status
}

// MARK: - Insights

struct Insight: Sendable, Identifiable {
    enum Kind: Sendable {
        case warning, opportunity, celebration, observation
    }
    enum Action: Sendable, Hashable {
        case viewSession(date: String)
        case openTrack(code: String)
        case share
        case snooze
        case dismiss

        var label: String {
            switch self {
            case .viewSession: return "View session"
            case .openTrack:   return "Open track"
            case .share:       return "Share"
            case .snooze:      return "Snooze 7d"
            case .dismiss:     return "Dismiss"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let title: String
    let body: String
    let action: Action?

    init(kind: Kind, title: String, body: String, action: Action?) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.body = body
        self.action = action
    }
}
