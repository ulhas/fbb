import SwiftUI

struct SubscriptionCard: View {
    let subscription: SubscriptionStatus
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscription")
                        .font(.fbb.label).tracking(1.0)
                        .foregroundStyle(Color.inkSecondary)
                    Text(subscription.planLabel)
                        .font(.fbb.title2)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                statusPill
            }

            // Renewal / price strip
            HStack(spacing: Spacing.lg) {
                if let price = subscription.priceLabel {
                    metric(label: "PRICE", value: price)
                }
                if let renews = subscription.renewsOn {
                    metric(label: "RENEWS", value: renewsLabel(renews))
                }
                if let trial = subscription.trialDaysLeft, trial > 0 {
                    metric(label: "TRIAL", value: "\(trial)d left")
                }
            }

            Divider().background(Color.fbbDivider)

            // Perks
            VStack(alignment: .leading, spacing: 6) {
                ForEach(subscription.perks, id: \.self) { perk in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.fbbOrange)
                        Text(perk)
                            .font(.fbb.body)
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

            Button(action: onManage) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Manage in App Store")
                        .font(.fbb.bodyBold)
                    Spacer()
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.fbbOrange)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Color.fbbOrangeTint.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.surfaceCard, Color.fbbOrangeTint.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner)
                .strokeBorder(Color.fbbOrange.opacity(0.25), lineWidth: 1)
        )
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.planLabel), \(subscription.isActive ? "active" : "inactive")")
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(subscription.isActive ? Color.semanticSuccess : Color.semanticWarning)
                .frame(width: 6, height: 6)
            Text(subscription.isActive ? "Active" : "Inactive")
                .font(.fbb.label)
                .foregroundStyle(subscription.isActive ? Color.semanticSuccess : Color.semanticWarning)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, Spacing.xs)
        .background(
            (subscription.isActive ? Color.semanticSuccess : Color.semanticWarning).opacity(0.12),
            in: Capsule()
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.fbb.label).tracking(1.0)
                .foregroundStyle(Color.inkMuted)
            Text(value)
                .font(.fbb.metric)
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private func renewsLabel(_ iso: String) -> String {
        guard let date = ISODate.parse(iso) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

#Preview {
    SubscriptionCard(
        subscription: ProfileMockData.subscription(now: Date()),
        onManage: {}
    )
    .padding()
    .background(Color.fbbBackground)
}
