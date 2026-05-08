import SwiftUI
import Charts

struct VolumeTrendCard: View {
    let points: [VolumePoint]

    @State private var scrubbed: VolumePoint?

    private var deloadDates: [String] {
        points.filter { $0.microcycleKind == .deload }.map(\.weekStartsOn)
    }

    private var prDates: [String] {
        points.filter(\.isPRWeek).map(\.weekStartsOn)
    }

    private var maxVolume: Double {
        max((points.map(\.volumeLb).max() ?? 0) * 1.08, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: "Weekly volume",
                subtitle: subtitleLabel,
                trailing: AnyView(legend)
            )

            chart
                .frame(height: 180)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var subtitleLabel: String {
        if let scrubbed {
            return "\(formatVolume(scrubbed.volumeLb)) lb · \(ISODate.monthDay(scrubbed.weekStartsOn))"
        }
        return "Last \(points.count) weeks"
    }

    private var chart: some View {
        Chart {
            ForEach(deloadDates, id: \.self) { iso in
                if let date = ISODate.parse(iso) {
                    RectangleMark(
                        xStart: .value("start", date.addingTimeInterval(-3 * 86_400)),
                        xEnd:   .value("end",   date.addingTimeInterval( 3 * 86_400 + 86_400)),
                        yStart: .value("y0", 0),
                        yEnd:   .value("y1", maxVolume)
                    )
                    .foregroundStyle(Color.byowTealTint.opacity(0.45))
                }
            }

            ForEach(points) { p in
                if let date = ISODate.parse(p.weekStartsOn) {
                    AreaMark(
                        x: .value("week", date),
                        y: .value("volume", p.volumeLb)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.byowOrange.opacity(0.34), Color.byowOrange.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("week", date),
                        y: .value("volume", p.volumeLb)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.byowOrange)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }

            ForEach(points.filter(\.isPRWeek)) { p in
                if let date = ISODate.parse(p.weekStartsOn) {
                    PointMark(
                        x: .value("week", date),
                        y: .value("volume", p.volumeLb)
                    )
                    .foregroundStyle(Color.byowOrange)
                    .symbol(.diamond)
                    .symbolSize(70)
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("PR")
                            .font(.byow.label)
                            .foregroundStyle(Color.byowOrange)
                    }
                }
            }

            if let scrubbed, let date = ISODate.parse(scrubbed.weekStartsOn) {
                RuleMark(x: .value("week", date))
                    .foregroundStyle(Color.inkMuted.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(
                    x: .value("week", date),
                    y: .value("volume", scrubbed.volumeLb)
                )
                .foregroundStyle(Color.byowOrangeDark)
                .symbolSize(110)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.inkMuted.opacity(0.18))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(compactVolume(v))
                            .font(.byow.caption.monospacedDigit())
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let xLocal = drag.location.x - geo.frame(in: .local).minX
                                guard let date: Date = proxy.value(atX: xLocal) else { return }
                                scrubbed = nearest(to: date)
                            }
                            .onEnded { _ in scrubbed = nil }
                    )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.sm) {
            Label {
                Text("Deload").font(.byow.label).foregroundStyle(Color.inkSecondary)
            } icon: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.byowTealTint.opacity(0.7))
                    .frame(width: 10, height: 10)
            }
            Label {
                Text("PR").font(.byow.label).foregroundStyle(Color.inkSecondary)
            } icon: {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(Color.byowOrange)
                    .imageScale(.small)
            }
        }
    }

    private func nearest(to date: Date) -> VolumePoint? {
        points.min(by: { lhs, rhs in
            let l = ISODate.parse(lhs.weekStartsOn) ?? .distantPast
            let r = ISODate.parse(rhs.weekStartsOn) ?? .distantPast
            return abs(l.timeIntervalSince(date)) < abs(r.timeIntervalSince(date))
        })
    }

    private func compactVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    private func formatVolume(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

#Preview {
    VolumeTrendCard(points: StatsMockData.trend(now: Date()))
        .padding()
        .background(Color.byowBackground)
}
