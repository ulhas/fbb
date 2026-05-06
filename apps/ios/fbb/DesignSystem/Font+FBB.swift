import SwiftUI

extension Font {
    enum FBB {
        // Display & headings — used on iOS hero surfaces.
        static let display    = Font.system(.largeTitle, design: .default, weight: .bold)
        static let title1     = Font.system(.title,      design: .default, weight: .bold)
        static let title2     = Font.system(.title2,     design: .default, weight: .semibold)
        static let title3     = Font.system(.title3,     design: .default, weight: .semibold)

        // Body & labels.
        static let body       = Font.system(.body,       design: .default, weight: .regular)
        static let bodyBold   = Font.system(.body,       design: .default, weight: .semibold)
        static let caption    = Font.system(.caption,    design: .default, weight: .regular)
        static let label      = Font.system(.caption2,   design: .default, weight: .semibold)
            .smallCaps()

        // Numeric metrics — tabular figures so big numbers don't jiggle as
        // they update. Use for weight, reps, duration, heart rate, streaks.
        static let metric     = Font.system(.title2, design: .rounded, weight: .semibold)
            .monospacedDigit()
        static let metricLarge = Font.system(.largeTitle, design: .rounded, weight: .bold)
            .monospacedDigit()
        static let metricHero  = Font.system(size: 64, weight: .bold, design: .rounded)
            .monospacedDigit()

        // watchOS / Widget compact glyphs.
        static let watchTitle  = Font.system(.headline,    design: .rounded, weight: .semibold)
        static let watchMetric = Font.system(.title3,      design: .rounded, weight: .bold)
            .monospacedDigit()
        static let widgetCaption = Font.system(.caption2,  design: .default,  weight: .semibold)

        // Code / IDs.
        static let mono       = Font.system(.subheadline, design: .monospaced, weight: .regular)
    }
    static var fbb: FBB.Type { FBB.self }
}
