import SwiftUI

/// Cross-platform primary CTA. Same brand color and press feel on iOS and
/// watchOS; iOS adds Liquid Glass, watchOS uses a flat fill (`.glassEffect`
/// is iOS-only). Callers use `.buttonStyle(.fbbPrimary)`.
public struct FBBPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        #if os(iOS)
        configuration.label
            .font(.fbb.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background(
                Color.fbbOrange.opacity(configuration.isPressed ? 0.85 : 1.0),
                in: RoundedRectangle(cornerRadius: Spacing.buttonCorner, style: .continuous)
            )
            .glassEffect(
                .regular.tint(.fbbOrange).interactive(),
                in: RoundedRectangle(cornerRadius: Spacing.buttonCorner, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
        #else
        configuration.label
            .font(.fbb.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(
                Color.fbbOrange.opacity(configuration.isPressed ? 0.80 : 1.0),
                in: RoundedRectangle(cornerRadius: Spacing.watchButtonCorner, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
        #endif
    }
}

public extension ButtonStyle where Self == FBBPrimaryButtonStyle {
    static var fbbPrimary: FBBPrimaryButtonStyle { FBBPrimaryButtonStyle() }
}

/// Translucent secondary CTA. Lower visual weight than the primary; same
/// brand corner radius and press feel.
public struct FBBSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.fbb.bodyBold)
            .foregroundStyle(Color.inkPrimary)
            #if os(iOS)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background(
                Color.surfaceCard.opacity(configuration.isPressed ? 0.85 : 1.0),
                in: RoundedRectangle(cornerRadius: Spacing.buttonCorner, style: .continuous)
            )
            #else
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(
                Color.surfaceCard.opacity(configuration.isPressed ? 0.80 : 1.0),
                in: RoundedRectangle(cornerRadius: Spacing.watchButtonCorner, style: .continuous)
            )
            #endif
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == FBBSecondaryButtonStyle {
    static var fbbSecondary: FBBSecondaryButtonStyle { FBBSecondaryButtonStyle() }
}
