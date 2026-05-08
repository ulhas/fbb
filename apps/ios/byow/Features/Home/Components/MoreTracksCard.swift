import SwiftUI

/// Inline CTA shown on Today when the user already follows ≥1 track. Lets
/// them re-take the quiz to add another match without leaving Today.
/// Sized smaller than `FindYourMatchCard` — it's an option, not the
/// primary action.
struct MoreTracksCard: View {
    let onStartQuiz: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onStartQuiz()
        }) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.byowOrange)
                    .frame(width: 38, height: 38)
                    .background(
                        Color.byowOrangeTint.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Want a different match?")
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                    Text("Take the quiz to add another track.")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.byowOrange)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.surfaceCard,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.byowOrange.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityHint("Opens the track quiz")
    }
}
