import SwiftUI
import Charts

struct TrackProgressionStrip: View {
    let tracks: [TrackProgression]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Tracks", subtitle: "Per-track volume · last 8 weeks")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(tracks) { TrackCard(track: $0) }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 1)   // avoids edge clipping of shadows
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct TrackCard: View {
    let track: TrackProgression

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: familySymbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text("\(track.intent.displayLabel) · Wk \(track.weekPosition)/\(track.weekTotal)")
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            sparkline
                .frame(height: 56)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color.fbbOrange)
                Text(track.topMover ?? "Building base volume")
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .frame(width: 240, alignment: .leading)
        .background(Color.surfaceCard)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
                .strokeBorder(track.isFocused ? accent : Color.clear, lineWidth: 1.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.displayName), \(track.intent.displayLabel), week \(track.weekPosition) of \(track.weekTotal). \(track.topMover ?? "")")
    }

    private var sparkline: some View {
        let pts = track.sparkline.enumerated().map { (idx, v) in
            (week: idx, vol: v)
        }
        return Chart {
            ForEach(pts, id: \.week) { p in
                AreaMark(
                    x: .value("week", p.week),
                    y: .value("vol", p.vol)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.42), accent.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("week", p.week),
                    y: .value("vol", p.vol)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let last = pts.last {
                PointMark(
                    x: .value("week", last.week),
                    y: .value("vol", last.vol)
                )
                .foregroundStyle(accent)
                .symbolSize(40)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }

    private var accent: Color {
        track.isFocused ? .fbbOrange : .fbbTeal
    }

    private var familySymbol: String {
        switch track.family {
        case .pumpLift:        return "dumbbell.fill"
        case .pumpCondition:   return "wind"
        case .perform:         return "flame.fill"
        case .minimalist:      return "circle.dashed"
        case .hybridRunning:   return "figure.run"
        case .workshop:        return "wrench.and.screwdriver.fill"
        case .onramp:          return "arrow.up.right"
        }
    }
}

#Preview {
    TrackProgressionStrip(tracks: StatsMockData.tracks(for: ["pump_lift_4x", "perform_5x"]))
        .padding(.vertical)
        .background(Color.fbbBackground)
}
