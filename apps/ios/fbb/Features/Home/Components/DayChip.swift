import SwiftUI

struct DayChip: View {
    let day: TrainingWeekDayMetaRow
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(ISODate.weekdayLetter(day.scheduledOn))
                    .font(.fbb.caption)
                    .foregroundStyle(isSelected ? Color.white : Color.inkMuted)

                Text("\(ISODate.dayOfMonth(day.scheduledOn) ?? 0)")
                    .font(.fbb.title3)
                    .foregroundStyle(isSelected ? Color.white : Color.inkPrimary)

                statusDot
            }
            .frame(width: 44, height: 64)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var glass: Glass {
        if isSelected { return .regular.tint(.fbbOrange).interactive() }
        if isToday    { return .regular.tint(.fbbOrangeTint).interactive() }
        return .regular.interactive()
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .frame(width: 6, height: 6)
            .foregroundStyle(dotColor)
    }

    private var dotColor: Color {
        if day.kind == .rest {
            return .inkMuted.opacity(0.5)
        }
        if isPast    { return .semanticSuccess }
        if isToday   { return .fbbOrangeDark }
        return .inkMuted.opacity(0.4)
    }

    private var a11yLabel: String {
        var parts: [String] = [
            ISODate.weekdayName(day.scheduledOn),
            ISODate.monthDay(day.scheduledOn),
        ]
        if isToday    { parts.append("today") }
        if isSelected { parts.append("selected") }
        if day.kind == .rest {
            parts.append("rest")
        } else {
            parts.append("\(day.sectionCount) sections")
        }
        return parts.joined(separator: ", ")
    }
}
