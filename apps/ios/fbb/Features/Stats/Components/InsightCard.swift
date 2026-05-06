import SwiftUI

struct InsightCard: View {
    let insight: Insight
    let onAction: (Insight.Action) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(kindTint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: kindSymbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(kindTint)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(insight.title)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.body)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let action = insight.action {
                    Button { onAction(action) } label: {
                        HStack(spacing: 4) {
                            Text(action.label)
                                .font(.fbb.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(kindTint)
                        .padding(.top, Spacing.xxs)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner)
                .strokeBorder(kindTint.opacity(0.18), lineWidth: 0.5)
        )
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kindLabel) insight: \(insight.title). \(insight.body)")
    }

    private var kindTint: Color {
        switch insight.kind {
        case .warning:     return .semanticWarning
        case .opportunity: return .fbbTeal
        case .celebration: return .fbbOrange
        case .observation: return .inkSecondary
        }
    }

    private var kindSymbol: String {
        switch insight.kind {
        case .warning:     return "exclamationmark.triangle.fill"
        case .opportunity: return "lightbulb.fill"
        case .celebration: return "trophy.fill"
        case .observation: return "eye.fill"
        }
    }

    private var kindLabel: String {
        switch insight.kind {
        case .warning:     return "Watch-out"
        case .opportunity: return "Opportunity"
        case .celebration: return "Celebration"
        case .observation: return "Observation"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(StatsMockData.insights) { insight in
            InsightCard(insight: insight, onAction: { _ in })
        }
    }
    .padding()
    .background(Color.fbbBackground)
}
