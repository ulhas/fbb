import SwiftUI

struct DaySwitcher: View {
    let days: [TrainingWeekDayMetaRow]
    let selectedDate: String?
    let todayISO: String
    let onSelect: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxs) {
                    ForEach(days) { day in
                        DayChip(
                            day: day,
                            isSelected: day.scheduledOn == selectedDate,
                            isToday:    day.scheduledOn == todayISO,
                            isPast:     day.scheduledOn < todayISO,
                            onTap: { onSelect(day.scheduledOn) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .transaction { tx in
                if reduceMotion { tx.disablesAnimations = true }
            }
            .padding(.vertical, Spacing.xxs)
        }
    }
}
