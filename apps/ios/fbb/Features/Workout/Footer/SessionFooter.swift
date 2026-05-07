import SwiftUI

/// Sticky bottom footer during the running phase, just *above* the
/// global TabView accessory bar. The accessory owns play/pause + tap-
/// to-surface. The footer owns the canonical "End workout" action,
/// because ending is destructive enough that it should require the
/// user to be looking at the workout.
struct SessionFooter: View {
    let session: WorkoutSession
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.isPaused ? "PAUSED" : "ELAPSED")
                        .font(.fbb.label).tracking(0.6)
                        .foregroundStyle(session.isPaused ? Color.fbbOrange : Color.inkSecondary)
                    Text(SessionMath.formatElapsed(session.totalElapsedSeconds(now: ctx.date)))
                        .font(.fbb.metric)
                        .foregroundStyle(Color.inkPrimary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button(action: onEnd) {
                    Text("End workout")
                        .font(.fbb.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 12)
                        .background(Color.fbbOrange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.inkMuted.opacity(0.15))
                    .frame(height: 1)
            }
        }
    }
}
