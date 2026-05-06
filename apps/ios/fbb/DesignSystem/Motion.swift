import SwiftUI

/// Motion tokens. Single source of truth for animation rhythm across iOS,
/// watchOS, and WidgetKit. Bezier(0.16, 1, 0.3, 1) is the "fluid" curve we
/// use for screen-level transitions; spring tokens are for tactile feedback
/// (press, selection, modal entry).
enum Motion {
    /// Press / chip selection. ~120ms, snappy.
    static let press: Animation = .spring(response: 0.28, dampingFraction: 0.86)

    /// Standard UI transitions (card change, tab switch). ~220ms.
    static let standard: Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.22)

    /// Hero / sheet entrance. Slightly slower with overshoot.
    static let hero: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    /// Subtle pulse for live indicators (heart rate, recording).
    static let pulse: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)

    /// Press scale factor for tactile cards / buttons.
    static let pressScale: CGFloat = 0.97

    /// Duration mirrors of the curves above, for use in places that don't
    /// take an `Animation` (e.g. transaction completion, timed reveals).
    enum Duration {
        static let press: Double = 0.12
        static let standard: Double = 0.22
        static let hero: Double = 0.42
    }
}
