import SwiftUI

/// Reusable empty-state scaffold for tabs that don't have content yet.
/// Stays on-brand (orange + ink + glass chip) so placeholders feel intentional.
struct ComingSoonScaffold: View {
    let symbol: String
    let title: String
    let subtitle: String
    var accent: Color = .byowOrange
    var ctaLabel: String? = nil
    var onCTA: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: symbol)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, Spacing.xs)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.byow.title1)
                    .foregroundStyle(.inkPrimary)

                Text(subtitle)
                    .font(.byow.body)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            GlassChip(isSelected: false, tint: accent) {
                Label("Coming soon", systemImage: "sparkles")
                    .font(.byow.label)
                    .foregroundStyle(.inkPrimary)
            }
            .padding(.top, Spacing.xs)

            if let ctaLabel, let onCTA {
                Button(ctaLabel, action: onCTA)
                    .buttonStyle(PrimaryGlassButtonStyle())
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.byowBackground)
    }
}

#Preview {
    ComingSoonScaffold(
        symbol: "person.3.fill",
        title: "Community",
        subtitle: "Train alongside everyone on Persist. Leaderboards, partner WODs, and weekly check-ins are on the way."
    )
}
