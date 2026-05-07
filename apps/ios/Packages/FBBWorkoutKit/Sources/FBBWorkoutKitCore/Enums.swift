import Foundation

// Mirrors packages/types/src/index.ts (TrackFamily, TrackCadence, DayKind, MicrocycleKind).
// Snake-case raw values are explicit because JSONDecoder.keyDecodingStrategy
// rewrites JSON *keys*, not enum *raw values*.

public enum TrackFamily: String, Codable, Sendable, CaseIterable, Hashable {
    case pumpLift       = "pump_lift"
    case pumpCondition  = "pump_condition"
    case perform
    case minimalist
    case hybridRunning  = "hybrid_running"
    case workshop
    case onramp

    public var displayLabel: String {
        switch self {
        case .pumpLift:       return "PUMP LIFT"
        case .pumpCondition:  return "PUMP CONDITION"
        case .perform:        return "PERFORM"
        case .minimalist:     return "MINIMALIST"
        case .hybridRunning:  return "HYBRID RUNNING"
        case .workshop:       return "WORKSHOP"
        case .onramp:         return "ON RAMP"
        }
    }
}

public enum TrackCadence: String, Codable, Sendable, Hashable {
    case x3 = "3x"
    case x4 = "4x"
    case x5 = "5x"
    case custom
}

public enum DayKind: String, Codable, Sendable, Hashable {
    case workout
    case activeRecovery = "active_recovery"
    case mobility
    case rest
    case lesson
}

public enum MicrocycleKind: String, Codable, Sendable, Hashable {
    case standard
    case bridgeWeek    = "bridge_week"
    case deload
    case orphanBridge  = "orphan_bridge"

    public var displayLabel: String {
        switch self {
        case .standard:     return "Training"
        case .bridgeWeek:   return "Bridge Week"
        case .deload:       return "Deload"
        case .orphanBridge: return "Bridge"
        }
    }
}

public enum MesocycleIntent: String, Codable, Sendable, Hashable, CaseIterable {
    case hypertrophy
    case strength
    case conditioning
    case mixed
    case deload

    public var displayLabel: String {
        switch self {
        case .hypertrophy:   return "Hypertrophy"
        case .strength:      return "Strength"
        case .conditioning:  return "Conditioning"
        case .mixed:         return "Mixed"
        case .deload:        return "Deload"
        }
    }
}
