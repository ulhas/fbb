import SwiftUI

struct GreetingHeader: View {
    let weekdayName: String
    let monthDay: String
    let microcycleLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(weekdayName.isEmpty ? "Today" : weekdayName)
                .font(.fbb.display)
                .foregroundStyle(.inkPrimary)

            HStack(spacing: Spacing.xs) {
                Text(monthDay)
                    .font(.fbb.body)
                    .foregroundStyle(.inkSecondary)
                if let microcycleLabel {
                    Text("·")
                        .font(.fbb.body)
                        .foregroundStyle(.inkMuted)
                    Text(microcycleLabel)
                        .font(.fbb.body)
                        .foregroundStyle(.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
