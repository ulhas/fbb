import SwiftUI
import Charts

struct MovementBalanceCard: View {
    let slices: [MovementBalanceSlice]

    private var totalSets: Int {
        slices.reduce(0) { $0 + $1.sets }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Movement balance", subtitle: "Volume distribution · last 14 days")

            HStack(alignment: .center, spacing: Spacing.lg) {
                donut
                    .frame(width: 160, height: 160)
                legend
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var donut: some View {
        ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("sets", slice.sets),
                    innerRadius: .ratio(0.66),
                    angularInset: 1.5
                )
                .cornerRadius(2)
                .foregroundStyle(color(for: slice))
            }
            VStack(spacing: 0) {
                Text("\(totalSets)")
                    .font(.fbb.metricLarge)
                    .foregroundStyle(Color.inkPrimary)
                Text("sets")
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .accessibilityLabel("Total \(totalSets) sets across \(slices.count) movement patterns")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(slices) { slice in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(color(for: slice))
                        .frame(width: 9, height: 9)
                    Text(slice.pattern)
                        .font(.fbb.caption.weight(.semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    if slice.isFlagged {
                        Image(systemName: "exclamationmark.circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(Color.semanticWarning)
                    }
                    Spacer()
                    Text("\(Int(slice.percent * 100))%")
                        .font(.fbb.caption.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    /// Map each slice to a tonal step in the brand palette so the donut feels
    /// cohesive rather than rainbow-y.
    private func color(for slice: MovementBalanceSlice) -> Color {
        let palette: [Color] = [
            .fbbOrange,
            .fbbOrangeDark,
            .fbbOrangeTint,
            .fbbTeal,
            .fbbTealDark,
            .fbbTealTint,
            .inkSecondary,
            .inkMuted,
        ]
        let idx = slices.firstIndex(where: { $0.id == slice.id }) ?? 0
        return palette[idx % palette.count]
    }
}

#Preview {
    MovementBalanceCard(slices: StatsMockData.balance)
        .padding()
        .background(Color.fbbBackground)
}
