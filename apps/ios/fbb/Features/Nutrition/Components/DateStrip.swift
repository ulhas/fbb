import SwiftUI

/// Horizontal 7-day pill strip. Each pill: weekday letter, day-of-month, and
/// a small dot indicating log status (untouched / partial / complete). Tap
/// to switch the active date for the rest of the page.
struct DateStrip: View {
    let days: [DateStripDay]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(days) { day in
                    DayPill(day: day, onTap: { onSelect(day.date) })
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
    }
}

private struct DayPill: View {
    let day: DateStripDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(ISODate.weekdayLetter(day.date))
                    .font(.fbb.label)
                    .foregroundStyle(day.isSelected ? .white : Color.inkSecondary)
                Text("\(ISODate.dayOfMonth(day.date) ?? 0)")
                    .font(.fbb.bodyBold)
                    .foregroundStyle(day.isSelected ? .white : Color.inkPrimary)
                    .monospacedDigit()
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(day.isSelected ? Color.fbbOrange : Color.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        day.isToday && !day.isSelected ? Color.fbbOrange.opacity(0.5) : .clear,
                        lineWidth: 1.4
                    )
            )
            .elevation(day.isSelected ? .raised : .card)
            .accessibilityLabel(label)
            .accessibilityAddTraits(day.isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }

    private var dotColor: Color {
        if day.isSelected {
            switch day.logState {
            case .complete:  return .white
            case .partial:   return .white.opacity(0.7)
            case .untouched: return .white.opacity(0.35)
            case .future:    return .clear
            }
        }
        switch day.logState {
        case .complete:  return .semanticSuccess
        case .partial:   return .fbbOrange
        case .untouched: return .inkMuted.opacity(0.5)
        case .future:    return .clear
        }
    }

    private var label: String {
        let weekday = ISODate.weekdayName(day.date)
        let monthDay = ISODate.monthDay(day.date)
        let stateLabel: String
        switch day.logState {
        case .complete:  stateLabel = "fully logged"
        case .partial:   stateLabel = "partially logged"
        case .untouched: stateLabel = "no logs"
        case .future:    stateLabel = "upcoming"
        }
        return "\(weekday) \(monthDay), \(stateLabel)"
    }
}

#Preview {
    DateStrip(
        days: NutritionMockData.build(
            for: ISODate.string(Date()),
            now: Date()
        ).dateStrip,
        onSelect: { _ in }
    )
    .background(Color.fbbBackground)
}
