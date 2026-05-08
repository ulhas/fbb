import SwiftUI

/// Domain-neutral row used by both Today's training picker and Nutrition's
/// log picker. The indicator is the only place data shape leaks into the
/// view: each domain pre-computes which dot (if any) to draw per date so
/// the picker stays unaware of training kinds vs. nutrition log states.
struct WeekDayPickerItem: Identifiable, Hashable {
    let date: String                    // ISO YYYY-MM-DD
    let indicator: Indicator?           // nil = no dot
    var id: String { date }

    enum Indicator: Hashable {
        case complete   // green — past workout done, fully logged
        case partial    // orange — partial log, today's session in progress
        case planned    // muted — scheduled but untouched
    }
}

/// One-stop week + day picker shared by Today and Nutrition. Chevrons step
/// a calendar week at a time (host decides what "week" means and disables
/// when no adjacent data exists). Visual hierarchy:
///
///   [<]   April · Week 5   [>]
///         Apr 20 – Apr 26
///
///   ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┐
///   │  M  │  T  │  W  │  T  │  F  │  S  │  S  │
///   │  20 │  21 │  22 │  23 │  24 │  25 │  26 │
///   └─────┴─────┴─────┴─────┴─────┴─────┴─────┘
struct WeekDayPicker: View {
    let items: [WeekDayPickerItem]
    let selectedDate: String?
    let todayISO: String
    let weekRangeLabel: String?
    let microcycleLabel: String?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onSelect: (String) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.sm) {
            header
            pillRow
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            chevron(systemName: "chevron.left", enabled: canGoPrevious, action: onPrevious)

            VStack(spacing: 2) {
                if let microcycleLabel {
                    Text(microcycleLabel.uppercased())
                        .font(.byow.label).tracking(1.2)
                        .foregroundStyle(Color.byowOrange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let weekRangeLabel {
                    Text(weekRangeLabel)
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            chevron(systemName: "chevron.right", enabled: canGoNext, action: onNext)
        }
        .padding(.horizontal, Spacing.xs)
    }

    private func chevron(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Color.byowOrange : Color.inkMuted)
                .frame(width: 36, height: 36)
                .background(
                    Color.byowOrangeTint.opacity(enabled ? 0.45 : 0.18),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous week" : "Next week")
    }

    // MARK: - Pills

    private var pillRow: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(items) { item in
                DayPill(
                    item: item,
                    isSelected: item.date == selectedDate,
                    isToday:    item.date == todayISO,
                    isPast:     item.date < todayISO,
                    onTap: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        onSelect(item.date)
                    }
                )
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: selectedDate)
    }
}

// MARK: - DayPill

private struct DayPill: View {
    let item: WeekDayPickerItem
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(ISODate.weekdayLetter(item.date))
                    .font(.byow.label).tracking(0.6)
                    .foregroundStyle(letterTint)

                Text("\(ISODate.dayOfMonth(item.date) ?? 0)")
                    .font(.byow.title3)
                    .foregroundStyle(numberTint)
                    .monospacedDigit()

                statusDot
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var background: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [Color.byowOrange, Color.byowOrangeDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if isToday {
                Color.byowOrangeTint.opacity(0.45)
            } else {
                Color.byowBackground.opacity(0.55)
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        if isToday && !isSelected {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.byowOrange.opacity(0.6), lineWidth: 1.4)
        } else if !isSelected {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.byowDivider.opacity(0.35), lineWidth: 1)
        }
    }

    private var letterTint: Color {
        if isSelected { return .white.opacity(0.85) }
        if isToday    { return .byowOrange }
        return .inkSecondary
    }

    private var numberTint: Color {
        if isSelected { return .white }
        if isToday    { return .byowOrange }
        if isPast     { return .inkSecondary }
        return .inkPrimary
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 5, height: 5)
            .opacity(item.indicator == nil ? 0 : 1)
    }

    private var dotColor: Color {
        guard let indicator = item.indicator else { return .clear }
        if isSelected { return .white.opacity(0.9) }
        switch indicator {
        case .complete: return .semanticSuccess.opacity(isPast ? 0.85 : 1.0)
        case .partial:  return .byowOrange
        case .planned:  return .inkMuted.opacity(0.6)
        }
    }

    private var a11yLabel: String {
        var parts: [String] = [
            ISODate.weekdayName(item.date),
            ISODate.monthDay(item.date),
        ]
        if isToday    { parts.append("today") }
        if isSelected { parts.append("selected") }
        switch item.indicator {
        case .complete: parts.append("complete")
        case .partial:  parts.append("partial")
        case .planned:  parts.append("planned")
        case .none:     break
        }
        return parts.joined(separator: ", ")
    }
}
