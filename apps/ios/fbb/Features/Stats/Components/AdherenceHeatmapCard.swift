import SwiftUI

struct AdherenceHeatmapCard: View {
    let cells: [AdherenceCell]
    let onTap: (AdherenceCell) -> Void

    /// 13 columns × 7 rows for the last 90 days. Most recent week sits on
    /// the right; weekday letter labels go down the left edge.
    private var columns: [[AdherenceCell]] {
        // Bucket sequentially into weeks of 7. Cells arrive oldest→newest.
        stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
    }

    private var completionRate: Int {
        let total = cells.filter { $0.status != .future && $0.status != .rest }.count
        let done = cells.filter { $0.status == .completed || $0.status == .exceeded }.count
        guard total > 0 else { return 0 }
        return Int(round(Double(done) / Double(total) * 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: "Adherence",
                subtitle: "Last 90 days · \(completionRate)% completion",
                trailing: AnyView(legend)
            )

            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                grid
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    private var weekdayLabels: some View {
        VStack(spacing: 4) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { letter in
                Text(letter)
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private var grid: some View {
        GeometryReader { geo in
            let cellSize = max(8, (geo.size.width - CGFloat(columns.count - 1) * 4) / CGFloat(columns.count))
            HStack(spacing: 4) {
                ForEach(Array(columns.enumerated()), id: \.offset) { (_, week) in
                    VStack(spacing: 4) {
                        ForEach(week) { cell in
                            cellView(cell, size: cellSize)
                        }
                        // Pad short weeks so columns stay aligned
                        ForEach(0..<(7 - week.count), id: \.self) { _ in
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(height: 7 * 14 + 6 * 4) // approx; baseline before geometry resolves
    }

    private func cellView(_ cell: AdherenceCell, size: CGFloat) -> some View {
        Button { onTap(cell) } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill(for: cell.status))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(stroke(for: cell.status), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ISODate.monthDay(cell.date)), \(label(for: cell.status))")
    }

    private func fill(for status: AdherenceCell.Status) -> Color {
        switch status {
        case .missed:    return Color.semanticError.opacity(0.22)
        case .skipped:   return Color.inkMuted.opacity(0.20)
        case .completed: return Color.fbbOrange.opacity(0.65)
        case .exceeded:  return Color.fbbOrange
        case .rest:      return Color.fbbDivider.opacity(0.5)
        case .future:    return Color.fbbDivider.opacity(0.18)
        }
    }

    private func stroke(for status: AdherenceCell.Status) -> Color {
        switch status {
        case .missed: return Color.semanticError.opacity(0.35)
        default:      return .clear
        }
    }

    private func label(for status: AdherenceCell.Status) -> String {
        switch status {
        case .missed:    return "missed"
        case .skipped:   return "skipped optional"
        case .completed: return "completed"
        case .exceeded:  return "exceeded prescription"
        case .rest:      return "scheduled rest"
        case .future:    return "upcoming"
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            ForEach([0.18, 0.40, 0.65, 1.0], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.fbbOrange.opacity(opacity))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

#Preview {
    AdherenceHeatmapCard(
        cells: StatsMockData.heatmap(now: Date()),
        onTap: { _ in }
    )
    .padding()
    .background(Color.fbbBackground)
}
