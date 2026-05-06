import SwiftUI

struct WeekRow: View {
    let row: TrainingWeekSummaryRow

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rangeLabel)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(.inkPrimary)

                HStack(spacing: Spacing.xs) {
                    if let kindLabel {
                        Text(kindLabel)
                            .font(.fbb.caption)
                            .foregroundStyle(kindColor)
                    }
                    if row.weekPosition != nil || kindLabel != nil { Text("·").foregroundStyle(.inkMuted).font(.fbb.caption) }
                    if let pos = row.weekPosition {
                        Text("Week \(pos)")
                            .font(.fbb.caption)
                            .foregroundStyle(.inkSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Text("\(row.parsedDayCount)/\(row.dayCount)")
                .font(.fbb.mono)
                .foregroundStyle(.inkSecondary)

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var rangeLabel: String {
        ISODate.rangeLabel(start: row.weekStartsOn, end: row.weekEndsOn)
    }

    private var kindLabel: String? {
        guard let raw = row.microcycleKind, let kind = MicrocycleKind(rawValue: raw) else { return nil }
        return kind.displayLabel
    }

    private var kindColor: Color {
        guard let raw = row.microcycleKind, let kind = MicrocycleKind(rawValue: raw) else { return .inkSecondary }
        switch kind {
        case .standard:                       return .inkSecondary
        case .bridgeWeek, .deload, .orphanBridge: return .semanticWarning
        }
    }

    private var a11yLabel: String {
        var parts: [String] = ["Week of \(rangeLabel)"]
        if let kindLabel { parts.append(kindLabel) }
        parts.append("\(row.parsedDayCount) of \(row.dayCount) days parsed")
        return parts.joined(separator: ", ")
    }

    static func skeleton() -> some View {
        WeekRow(row: .placeholder).redacted(reason: .placeholder)
    }
}
