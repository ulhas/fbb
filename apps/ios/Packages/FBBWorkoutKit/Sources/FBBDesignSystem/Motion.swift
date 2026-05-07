import SwiftUI

/// Motion tokens. Single source of truth for animation rhythm across iOS
/// and watchOS. Bezier(0.16, 1, 0.3, 1) is the "fluid" curve used for
/// screen-level transitions; spring tokens are for tactile feedback
/// (press, selection, modal entry).
public enum Motion {
    public static let press: Animation = .spring(response: 0.28, dampingFraction: 0.86)
    public static let standard: Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.22)
    public static let hero: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    public static let pulse: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    public static let pressScale: CGFloat = 0.97

    public enum Duration {
        public static let press: Double = 0.12
        public static let standard: Double = 0.22
        public static let hero: Double = 0.42
    }
}
