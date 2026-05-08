import Foundation

/// All weights are stored canonically in kg. Display + entry are unit-
/// aware. Conversions use the lifting-conventional 2.20462 lb/kg.
enum WeightUnitFormatter {
    private static let kgPerLb: Double = 0.45359237
    private static let lbPerKg: Double = 1.0 / kgPerLb

    /// Format a kg value for display in the user's preferred unit.
    /// - 5 lb / 2.5 kg increments aren't snapped — the display is just the
    ///   raw conversion. Snapping happens at input time.
    static func format(kg: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kg:
            return formatNumber(kg) + " kg"
        case .lb:
            return formatNumber(kg * lbPerKg) + " lb"
        }
    }

    /// Convert a user-entered display value to canonical kg.
    static func toKg(value: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return value
        case .lb: return value * kgPerLb
        }
    }

    /// Convert a canonical kg value to the display unit.
    static func toDisplay(kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return kg
        case .lb: return kg * lbPerKg
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        // Drop trailing zeros: 60.0 -> "60", 22.5 -> "22.5".
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
