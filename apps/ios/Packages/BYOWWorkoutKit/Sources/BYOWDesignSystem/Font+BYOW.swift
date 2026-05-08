import SwiftUI

public extension Font {
    enum BYOW {
        public static let display    = Font.system(.largeTitle, design: .default, weight: .bold)
        public static let title1     = Font.system(.title,      design: .default, weight: .bold)
        public static let title2     = Font.system(.title2,     design: .default, weight: .semibold)
        public static let title3     = Font.system(.title3,     design: .default, weight: .semibold)

        public static let body       = Font.system(.body,       design: .default, weight: .regular)
        public static let bodyBold   = Font.system(.body,       design: .default, weight: .semibold)
        public static let caption    = Font.system(.caption,    design: .default, weight: .regular)
        public static let label      = Font.system(.caption2,   design: .default, weight: .semibold)
            .smallCaps()

        public static let metric     = Font.system(.title2, design: .rounded, weight: .semibold)
            .monospacedDigit()
        public static let metricLarge = Font.system(.largeTitle, design: .rounded, weight: .bold)
            .monospacedDigit()
        public static let metricHero  = Font.system(size: 64, weight: .bold, design: .rounded)
            .monospacedDigit()

        // watchOS / Widget compact glyphs.
        public static let watchTitle      = Font.system(.headline,    design: .rounded, weight: .semibold)
        public static let watchMetric     = Font.system(.title3,      design: .rounded, weight: .bold)
            .monospacedDigit()
        /// Hero numeric on watch (reps/weight cells, rest countdown).
        public static let watchMetricHero = Font.system(size: 36, weight: .bold, design: .rounded)
            .monospacedDigit()
        public static let widgetCaption   = Font.system(.caption2,    design: .default, weight: .semibold)

        public static let mono       = Font.system(.subheadline, design: .monospaced, weight: .regular)
    }
    static var byow: BYOW.Type { BYOW.self }
}
