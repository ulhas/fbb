import SwiftUI

struct WeekStrip: View {
    let days: [TrainingWeekDayMetaRow]
    let selectedDate: String?
    let todayISO: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("This Week")
                .font(.fbb.title3)
                .foregroundStyle(.inkPrimary)
                .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(days) { day in
                        WeekStripCell(
                            day: day,
                            isSelected: day.scheduledOn == selectedDate,
                            isToday:    day.scheduledOn == todayISO,
                            onTap: { onSelect(day.scheduledOn) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
            }
        }
    }
}
