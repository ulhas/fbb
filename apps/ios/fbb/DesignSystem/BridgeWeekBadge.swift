import SwiftUI

struct BridgeWeekBadge: View {
    var body: some View {
        Label {
            Text("Bridge Week — Deload")
                .font(.fbb.caption)
                .foregroundStyle(Color.semanticWarning)
        } icon: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .foregroundStyle(Color.semanticWarning)
                .imageScale(.small)
        }
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.sm)
        .glassEffect(.regular.tint(.fbbTealTint), in: .capsule)
        .accessibilityLabel("Bridge week, deload week")
    }
}

#Preview {
    BridgeWeekBadge()
        .padding()
        .background(Color.fbbBackground)
}
