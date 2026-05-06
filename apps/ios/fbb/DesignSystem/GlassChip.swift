import SwiftUI

struct GlassChip<Label: View>: View {
    let isSelected: Bool
    var tint: Color = .fbbOrange
    @ViewBuilder var label: () -> Label

    var body: some View {
        label()
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .glassEffect(
                isSelected
                    ? .regular.tint(tint).interactive()
                    : .regular.interactive(),
                in: .capsule
            )
    }
}
