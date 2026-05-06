import SwiftUI

/// Centerpiece of the Stats page. The "coach reading your week" card.
/// Liquid-glass surface + warm gradient wash so it visually outranks the
/// data cards below.
struct HeroInsightCard: View {
    let insight: HeroInsight
    let onRefresh: () async -> Void
    let onWhy: () -> Void

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR WEEK")
                    .font(.fbb.label)
                    .tracking(1.4)
                    .foregroundStyle(Color.inkSecondary)

                Spacer(minLength: Spacing.xs)

                Button {
                    Task {
                        isRefreshing = true
                        await onRefresh()
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                            value: isRefreshing
                        )
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Refresh coach read")
            }

            Text(insight.body)
                .font(.fbb.body)
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.sm) {
                Button(action: onWhy) {
                    Label("Why this read?", systemImage: "sparkles")
                        .font(.fbb.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.fbbOrange.opacity(0.85))
                .controlSize(.small)
                .clipShape(Capsule())

                Spacer()

                Text("— \(insight.signature) · \(insight.freshnessLabel)")
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.fbbOrangeTint.opacity(0.32),
                        Color.fbbTealTint.opacity(0.20),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [Color.surfaceCard.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
        )
        .elevation(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your week: \(insight.body)")
    }
}

#Preview {
    HeroInsightCard(
        insight: StatsMockData.heroes[0],
        onRefresh: { },
        onWhy: { }
    )
    .padding()
    .background(Color.fbbBackground)
}
