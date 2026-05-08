import SwiftUI

struct CoachCard: View {
    let coach: CoachAssignment
    let onMessage: () -> Void
    let onChangePersonality: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header — coach person
            HStack(alignment: .center, spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.byowTeal, .byowTealDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(coach.firstName.prefix(1))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Coach \(coach.firstName)")
                        .font(.byow.title3)
                        .foregroundStyle(Color.inkPrimary)
                    Text(coach.role)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Text("Last check-in \(checkInLabel)")
                        .font(.byow.label).tracking(0.8)
                        .foregroundStyle(Color.byowTeal)
                }

                Spacer()
            }

            Button(action: onMessage) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Message coach")
                        .font(.byow.bodyBold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.byowTeal)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Color.byowTealTint.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Divider().background(Color.byowDivider)

            // AI personality picker
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.byowTeal)
                    Text("AI Coach personality")
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                }

                Text(coach.aiPersonality.detail)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onChangePersonality) {
                    HStack {
                        Text("Currently: \(coach.aiPersonality.displayLabel)")
                            .font(.byow.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.byowTeal)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                    .background(Color.byowTealTint.opacity(0.45), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .accessibilityElement(children: .contain)
    }

    private var checkInLabel: String {
        switch coach.lastCheckInDays {
        case 0: return "today"
        case 1: return "yesterday"
        default: return "\(coach.lastCheckInDays) days ago"
        }
    }
}

#Preview {
    CoachCard(
        coach: ProfileMockData.coach,
        onMessage: {},
        onChangePersonality: {}
    )
    .padding()
    .background(Color.byowBackground)
}
