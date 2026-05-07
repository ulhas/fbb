import SwiftUI

public struct CardStyle: ViewModifier {
    public var padded: Bool

    public init(padded: Bool = true) {
        self.padded = padded
    }

    public func body(content: Content) -> some View {
        content
            .padding(padded ? Spacing.md : 0)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

public extension View {
    func cardStyle(padded: Bool = true) -> some View {
        modifier(CardStyle(padded: padded))
    }
}
