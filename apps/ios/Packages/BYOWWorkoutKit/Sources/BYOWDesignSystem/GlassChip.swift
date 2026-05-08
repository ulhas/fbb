import SwiftUI

/// Pill-shaped chip. iOS uses Liquid Glass; watchOS falls back to a tinted
/// capsule (no `.glassEffect` on watchOS). Same brand colors, same radius
/// shape (capsule), same press feel.
public struct GlassChip<Label: View>: View {
    public let isSelected: Bool
    public var tint: Color
    @ViewBuilder public var label: () -> Label

    public init(
        isSelected: Bool,
        tint: Color = .byowOrange,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        #if os(iOS)
        label()
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .glassEffect(
                isSelected
                    ? .regular.tint(tint).interactive()
                    : .regular.interactive(),
                in: .capsule
            )
        #else
        label()
            .padding(.vertical, Spacing.xxs)
            .padding(.horizontal, Spacing.xs)
            .background(
                (isSelected ? tint : Color.surfaceCard).opacity(isSelected ? 1.0 : 0.6),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .inkPrimary)
        #endif
    }
}
