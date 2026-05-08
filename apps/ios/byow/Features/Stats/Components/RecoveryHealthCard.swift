import SwiftUI
import Charts

struct RecoveryHealthCard: View {
    let snapshot: RecoverySnapshot

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(
                title: "Recovery & Health",
                subtitle: "From Apple Health · synced \(snapshot.lastSyncedLabel)",
                trailing: AnyView(coachReadsChip)
            )

            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                MetricTile(metric: snapshot.sleep)
                MetricTile(metric: snapshot.hrv)
                MetricTile(metric: snapshot.restingHR)
                MetricTile(metric: snapshot.steps)
            }

            BodyWeightStrip(weight: snapshot.weight)
        }
    }

    private var coachReadsChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text("AI Coach reads this")
                .font(.byow.label)
        }
        .foregroundStyle(Color.byowTeal)
        .padding(.vertical, 4)
        .padding(.horizontal, Spacing.xs)
        .background(Color.byowTealTint.opacity(0.55), in: Capsule())
    }
}

// MARK: - Metric tile

private struct MetricTile: View {
    let metric: HealthMetric

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: metric.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stateTint)
                Text(metric.label.uppercased())
                    .font(.byow.label)
                    .tracking(1.0)
                    .foregroundStyle(Color.inkSecondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                Text(metric.value)
                    .font(.byow.metricLarge)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let unit = metric.unit {
                    Text(unit)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            sparkline
                .frame(height: 24)

            if let delta = metric.deltaLabel {
                Text(delta)
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(stateTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.label) \(metric.value) \(metric.unit ?? ""). \(metric.deltaLabel ?? "")")
    }

    private var sparkline: some View {
        let pts = metric.spark.enumerated().map { (idx, v) in (i: idx, v: v) }
        return Chart {
            ForEach(pts, id: \.i) { p in
                LineMark(
                    x: .value("i", p.i),
                    y: .value("v", p.v)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(stateTint)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                AreaMark(
                    x: .value("i", p.i),
                    y: .value("v", p.v)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [stateTint.opacity(0.28), stateTint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }

    private var stateTint: Color {
        switch metric.state {
        case .gaining:  return .byowOrange
        case .onPlan:   return .byowTeal
        case .lagging:  return .semanticWarning
        case .neutral:  return .inkSecondary
        }
    }
}

// MARK: - Body weight strip

private struct BodyWeightStrip: View {
    let weight: BodyWeightTrend

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BODY WEIGHT")
                        .font(.byow.label)
                        .tracking(1.0)
                        .foregroundStyle(Color.inkSecondary)
                    if let lb = weight.latestLb {
                        HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                            Text(String(format: "%.1f", lb))
                                .font(.byow.metric)
                                .foregroundStyle(Color.inkPrimary)
                            Text("lb")
                                .font(.byow.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
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
                .frame(height: 56)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body weight \(weight.points.last?.weightLb ?? 0, specifier: "%.1f") pounds. \(weight.trendLabel)")
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

// Workaround: SwiftUI accessibilityLabel doesn't accept Text formatter syntax,
// but Swift String interpolation with `specifier:` only exists on `Text`.
// So we add a local Specifier-style helper.
private extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: Double, specifier: String) {
        appendLiteral(String(format: specifier, value))
    }
}

#Preview {
    RecoveryHealthCard(snapshot: StatsMockData.recovery(now: Date()))
        .padding()
        .background(Color.byowBackground)
}
