import SwiftUI

/// Tinted pill button — strong enough to read at a glance against
/// the surrounding white card, without competing visually with the
/// primary "End workout" CTA. Used at round headers (RoundMajor) and
/// exercise headers (ExerciseMajor) when there's more than one set to
/// chord-complete.
struct MarkAllCompleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                Text("Complete all")
                    .font(.byow.caption.weight(.heavy))
            }
            .foregroundStyle(Color.byowOrange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.byowOrangeTint)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark all sets complete")
    }
}
