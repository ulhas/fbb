import SwiftUI

/// Empty-state hero on Today when the user has no active follows. Mirrors
/// BYOW live's "ONGOING TRAINING / FIND YOUR MATCH / TAKE TRACK QUIZ"
/// pattern so users coming from that app feel at home. Tapping the CTA
/// presents `TrackQuizSheet`.
struct FindYourMatchCard: View {
    let onStartQuiz: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ONGOING TRAINING")
                    .font(.byow.label).tracking(1.4)
                    .foregroundStyle(Color.inkSecondary)
                Text("Find your match")
                    .font(.byow.title1)
                    .foregroundStyle(Color.inkPrimary)
                Text("Answer a few questions and we'll curate the right track for how you train, what gear you have, and how often you can show up.")
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onStartQuiz()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("TAKE TRACK QUIZ")
                }
                .font(.byow.bodyBold)
                .tracking(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PressedScaleButtonStyle())
            .background(
                LinearGradient(
                    colors: [Color.byowOrange, Color.byowOrangeDark],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .padding(.top, Spacing.xs)

            previewStripe
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner)
                .strokeBorder(Color.byowOrange.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    /// Hint at the available track families so the user knows what's behind
    /// the curtain — keeps the card from feeling like a black-box quiz.
    private var previewStripe: some View {
        HStack(spacing: Spacing.xs) {
            FamilyChip(symbol: "dumbbell.fill", label: "Lift")
            FamilyChip(symbol: "wind",          label: "Condition")
            FamilyChip(symbol: "flame.fill",    label: "Perform")
            FamilyChip(symbol: "circle.dashed", label: "Minimalist")
        }
    }

    private var cardBackground: some View {
        ZStack(alignment: .top) {
            Color.surfaceCard
            LinearGradient(
                colors: [
                    Color.byowOrange.opacity(0.18),
                    Color.byowOrange.opacity(0.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 130)
        }
    }
}

private struct FamilyChip: View {
    let symbol: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.byowOrange)
                .frame(width: 36, height: 36)
                .background(
                    Color.byowOrangeTint.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            Text(label)
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
