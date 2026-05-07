import SwiftUI

/// Cross-platform scale-on-press button style. Used directly on watchOS where
/// `.glassEffect` is unavailable, and as the press-feedback layer underneath
/// `PrimaryGlassButtonStyle` on iOS.
public struct PressedScaleButtonStyle: ButtonStyle {
    public var scale: CGFloat

    public init(scale: CGFloat = Motion.pressScale) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PressedScaleButtonStyle {
    static var pressedScale: PressedScaleButtonStyle { PressedScaleButtonStyle() }
}
