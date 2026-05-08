import SwiftUI

/// Shown in two states:
///   - Prompt: "Rest 60 seconds" with a Rest button (idle, before user taps Rest)
///   - Active: live countdown ticking down (after user taps Rest)
///
/// Two separate views to keep state management simple — the parent
/// chooses which to render based on whether `inlineRests` has an entry
/// for this position.

/// The active countdown row.
struct InlineRestRow: View {
    let rest: InlineRestState
    let session: WorkoutSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let remaining = rest.remainingSeconds(now: ctx.date)
            HStack(spacing: Spacing.sm) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.byowOrange)
                Text("Rest")
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 0)
                Text(SessionMath.formatCountdown(remaining))
                    .font(.byow.metric)
                    .foregroundStyle(remaining < 0 ? .red : Color.inkPrimary)
                    .monospacedDigit()
                Button {
                    session.dismissInlineRest(rest.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("Skip")
                        .font(.byow.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.inkMuted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Color.byowTealTint.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// The idle prompt row, before the user has tapped Rest.
struct RestPromptRow: View {
    let seconds: Int
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("Rest \(seconds) seconds")
                .font(.byow.body)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
            Button(action: onStart) {
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Rest")
                        .font(.byow.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.byowOrange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}
