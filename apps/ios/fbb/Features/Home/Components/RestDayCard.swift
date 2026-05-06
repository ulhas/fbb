import SwiftUI

struct RestDayCard: View {
    let day: ParsedDay

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(.fbbTeal)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest day")
                    .font(.fbb.title3)
                    .foregroundStyle(.inkPrimary)
                Text(subtitle)
                    .font(.fbb.caption)
                    .foregroundStyle(.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        day.coachingNotes.first?.title ?? "Recover. Hydrate. Sleep well."
    }
}
