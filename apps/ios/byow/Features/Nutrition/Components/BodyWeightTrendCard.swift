import SwiftUI
import Charts

/// Smaller version of the Stats Recovery weight strip — same data, lighter
/// chrome since the Nutrition page already has its own visual weight.
struct BodyWeightTrendCard: View {
    let weight: BodyWeightTrend

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body weight")
                        .font(.byow.title3)
                        .foregroundStyle(Color.inkPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.byowTeal)
                        Text("From Apple Health")
                            .font(.byow.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer()
                Text(weight.trendLabel)
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.byowTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            chart
                .frame(height: 80)

            if let latest = weight.latestLb {
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", latest))
                        .font(.byow.metric)
                        .foregroundStyle(Color.inkPrimary)
                    Text("lb")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text("today")
                        .font(.byow.label)
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var chart: some View {
        Chart {
            ForEach(weight.points) { p in
                if let date = ISODate.parse(p.date) {
                    LineMark(
                        x: .value("date", date),
                        y: .value("lb", p.weightLb)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.byowTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    AreaMark(
                        x: .value("date", date),
                        y: .value("lb", p.weightLb)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.byowTeal.opacity(0.28), Color.byowTeal.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}

#Preview {
    BodyWeightTrendCard(weight: StatsMockData.bodyWeight(now: Date()))
        .padding()
        .background(Color.byowBackground)
}
