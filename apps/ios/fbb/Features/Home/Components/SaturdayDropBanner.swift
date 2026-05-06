import SwiftUI

struct SaturdayDropBanner: View {
    let weekRangeLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.fbbOrange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New week available")
                        .font(.fbb.bodyBold)
                        .foregroundStyle(.inkPrimary)
                    Text(weekRangeLabel)
                        .font(.fbb.caption)
                        .foregroundStyle(.inkSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(.fbbOrangeTint).interactive(),
                in: RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New week available, \(weekRangeLabel). Tap to view.")
    }
}
