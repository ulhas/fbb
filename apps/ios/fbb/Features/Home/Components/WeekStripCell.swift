import SwiftUI

struct WeekStripCell: View {
    let day: TrainingWeekDayMetaRow
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxs) {
                    Text(ISODate.weekdayLetter(day.scheduledOn))
                        .font(.fbb.caption)
                        .foregroundStyle(.inkMuted)
                    if isToday {
                        Text("Today")
                            .font(.fbb.caption)
                            .foregroundStyle(.fbbOrange)
                    }
                }

                Text(day.displayName)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(.inkPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    if day.kind == .rest {
                        Image(systemName: "moon.zzz")
                            .imageScale(.small)
                            .foregroundStyle(.fbbTeal)
                        Text("Rest")
                    } else {
                        Image(systemName: "checklist")
                            .imageScale(.small)
                            .foregroundStyle(.fbbTeal)
                        Text("\(day.sectionCount) sections")
                    }
                }
                .font(.fbb.caption)
                .foregroundStyle(.inkMuted)
            }
            .frame(width: 156, alignment: .leading)
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
                    .stroke(isSelected ? Color.fbbOrange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var a11yLabel: String {
        var parts: [String] = [
            ISODate.weekdayName(day.scheduledOn),
            day.displayName,
        ]
        if isToday    { parts.append("today") }
        if isSelected { parts.append("selected") }
        if day.kind == .rest {
            parts.append("rest day")
        } else {
            parts.append("\(day.sectionCount) sections")
        }
        return parts.joined(separator: ", ")
    }
}
