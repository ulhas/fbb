import SwiftUI
import Charts

struct WeeklyCaloriesCard: View {
    let days: [DailyCalories]

    @State private var scrubbed: DailyCalories?

    private var avg: Int {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.kcal } / days.count
    }

    private var target: Int { days.first?.target ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly calories")
                        .font(.fbb.title3)
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitleLabel)
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                avgBadge
            }

            chart
                .frame(height: 140)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var subtitleLabel: String {
        if let scrubbed {
            return "\(scrubbed.kcal) kcal · \(ISODate.monthDay(scrubbed.date))"
        }
        return "Last 7 days · target \(target) kcal"
    }

    private var avgBadge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("AVG")
                .font(.fbb.label)
                .foregroundStyle(Color.inkMuted)
            Text("\(avg)")
                .font(.fbb.metric)
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
        }
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                if let date = ISODate.parse(day.date) {
                    BarMark(
                        x: .value("date", date, unit: .day),
                        y: .value("kcal", day.kcal),
                        width: .ratio(0.6)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(tint(for: day.status))
                }
            }
            RuleMark(y: .value("target", target))
                .foregroundStyle(Color.inkMuted.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("target")
                        .font(.fbb.label)
                        .foregroundStyle(Color.inkMuted)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .chartYAxis(.hidden)
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

    private func tint(for status: DailyCalories.Status) -> Color {
        switch status {
        case .under: return .semanticWarning
        case .hit:   return .semanticSuccess
        case .over:  return .fbbOrange
        }
    }

    private func nearest(to date: Date) -> DailyCalories? {
        days.min(by: { lhs, rhs in
            let l = ISODate.parse(lhs.date) ?? .distantPast
            let r = ISODate.parse(rhs.date) ?? .distantPast
            return abs(l.timeIntervalSince(date)) < abs(r.timeIntervalSince(date))
        })
    }
}

#Preview {
    let day = NutritionMockData.build(for: ISODate.string(Date()), now: Date())
    return WeeklyCaloriesCard(days: day.weekly)
        .padding()
        .background(Color.fbbBackground)
}
