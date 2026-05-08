import SwiftUI

/// Compact pill describing the prescription mode of a section: "EMOM 12",
/// "AMRAP 20", "Strength", "For Time", etc. Lives in the hero card under
/// each section row.
struct PrescriptionBadge: View {
    let mode: String
    let durationMin: Int?
    let durationMax: Int?

    var body: some View {
        Text(label)
            .font(.byow.caption)
            .foregroundStyle(.inkSecondary)
            .padding(.vertical, 2)
            .padding(.horizontal, Spacing.xs)
            .background(Color.byowTealTint, in: Capsule())
            .accessibilityLabel(label)
    }

    private var label: String {
        let modeLabel: String
        switch mode {
        case "emom":             modeLabel = "EMOM"
        case "e2mom":            modeLabel = "E2MOM"
        case "e3mom":            modeLabel = "E3MOM"
        case "every_x_minutes":  modeLabel = "Every X"
        case "amrap":            modeLabel = "AMRAP"
        case "for_time":         modeLabel = "For Time"
        case "tabata":           modeLabel = "Tabata"
        case "rounds":           modeLabel = "Rounds"
        case "density":          modeLabel = "Density"
        case "interval_pyramid": modeLabel = "Pyramid"
        case "continuous_effort":modeLabel = "Continuous"
        case "straight_sets":    modeLabel = "Strength"
        case "free":             modeLabel = "Mixed"
        default: modeLabel = mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
        if let durationLabel { return "\(modeLabel) · \(durationLabel)" }
        return modeLabel
    }

    private var durationLabel: String? {
        switch (durationMin, durationMax) {
        case let (min?, max?) where min == max: return "\(min) min"
        case let (min?, max?):                  return "\(min)–\(max) min"
        case let (min?, nil):                   return "\(min) min"
        case (nil, let max?):                   return "\(max) min"
        case (nil, nil):                        return nil
        }
    }
}
