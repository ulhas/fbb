import SwiftUI

/// Compact pill that summarizes the user's current microcycle context.
/// Mirrors `BridgeWeekBadge` styling but adapts copy + tint by kind.
struct MicrocycleChip: View {
    let context: MicrocycleContext

    var body: some View {
        Label {
            Text(context.summary)
                .font(.fbb.caption)
                .foregroundStyle(tint)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .imageScale(.small)
        }
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.sm)
        .glassEffect(.regular.tint(glassTint), in: .capsule)
        .accessibilityLabel("Current microcycle: \(context.summary)")
    }

    private var symbol: String {
        switch context.kind {
        case .bridgeWeek, .orphanBridge: return "arrow.down.right.and.arrow.up.left"
        case .deload:                    return "tortoise.fill"
        case .standard:
            switch context.intent {
            case .strength:      return "dumbbell.fill"
            case .hypertrophy:   return "figure.strengthtraining.traditional"
            case .conditioning:  return "wind"
            case .mixed:         return "circle.grid.cross.fill"
            case .deload, nil:   return "flame.fill"
            }
        }
    }

    private var tint: Color {
        switch context.kind {
        case .bridgeWeek, .orphanBridge, .deload: return .semanticWarning
        case .standard: return .fbbOrange
        }
    }

    private var glassTint: Color {
        switch context.kind {
        case .bridgeWeek, .orphanBridge, .deload: return .fbbTealTint
        case .standard: return .fbbOrangeTint
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MicrocycleChip(context: MicrocycleContext(kind: .standard, intent: .strength, weekPosition: 3, weekTotal: 5))
        MicrocycleChip(context: MicrocycleContext(kind: .standard, intent: .hypertrophy, weekPosition: 2, weekTotal: 4))
        MicrocycleChip(context: MicrocycleContext(kind: .deload, intent: .deload, weekPosition: 1, weekTotal: 1))
        MicrocycleChip(context: MicrocycleContext(kind: .bridgeWeek, intent: nil, weekPosition: nil, weekTotal: nil))
    }
    .padding()
    .background(Color.fbbBackground)
}
