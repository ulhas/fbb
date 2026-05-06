import SwiftUI

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.fbb.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background(
                Color.fbbOrange.opacity(configuration.isPressed ? 0.8 : 1.0),
                in: RoundedRectangle(cornerRadius: Spacing.buttonCorner, style: .continuous)
            )
            .glassEffect(
                .regular.tint(.fbbOrange).interactive(),
                in: RoundedRectangle(cornerRadius: Spacing.buttonCorner, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryGlassButtonStyle {
    static var primaryGlass: PrimaryGlassButtonStyle { PrimaryGlassButtonStyle() }
}
