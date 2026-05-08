import SwiftUI

struct ProfileHeroCard: View {
    let user: UserHeader
    let tier: SubscriptionStatus.Tier

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.byow.title2)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(user.email)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    tierBadge
                    Text("·")
                        .foregroundStyle(Color.inkMuted)
                    Text("\(user.totalWeeksTrained) wk · since \(memberSinceLabel)")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.byowOrangeTint.opacity(0.45),
                    Color.byowTealTint.opacity(0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.fullName), \(user.email), \(tier.displayLabel) member, \(user.totalWeeksTrained) weeks trained")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.byowOrange, .byowOrangeDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )

            Text(user.initials)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Tier glyph in the lower-right
            if tier != .free {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.byowTeal, in: Circle())
                    .overlay(
                        Circle().strokeBorder(.white, lineWidth: 1.5)
                    )
                    .offset(x: 28, y: 28)
            }
        }
        .frame(width: 80, height: 80)
    }

    private var tierBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: tier == .free ? "circle" : "checkmark.seal.fill")
                .font(.system(size: 9, weight: .bold))
            Text(tier.displayLabel)
                .font(.byow.label)
        }
        .foregroundStyle(tier == .free ? Color.inkSecondary : Color.byowTeal)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            (tier == .free ? Color.inkMuted.opacity(0.15) : Color.byowTealTint.opacity(0.6)),
            in: Capsule()
        )
    }

    private var memberSinceLabel: String {
        guard let date = ISODate.parse(user.memberSince) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}

#Preview {
    ProfileHeroCard(
        user: ProfileMockData.user(now: Date()),
        tier: .plus
    )
    .padding()
    .background(Color.byowBackground)
}
