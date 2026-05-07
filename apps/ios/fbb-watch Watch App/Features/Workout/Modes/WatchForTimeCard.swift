import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// For Time mode: timer counts up; user taps Done when finished. If a soft
/// cap is set, the ring fills as the cap approaches and the timer flips
/// red past the cap.
struct WatchForTimeCard: View {
    let session: WorkoutSession
    let state: CapState

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let elapsed = state.elapsedSeconds(now: now)
        let cappedRemaining = max(0, state.remainingSeconds(now: now))
        let pastCap = state.remainingSeconds(now: now) < 0

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            WatchModeTopBar(session: session, modeLabel: "For Time")

            HStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .stroke(Color.inkMuted.opacity(0.25), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: pastCap ? 1.0 : Double(elapsed) / Double(max(1, state.capSeconds)))
                        .stroke(
                            pastCap ? Color.fbbStop : Color.fbbOrange,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text(SessionMath.formatElapsed(elapsed))
                        .font(.fbb.watchMetricHero)
                        .foregroundStyle(pastCap ? Color.fbbStop : Color.inkPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
                .frame(width: 88, height: 88)

                if let group = CursorAdvance.currentGroup(session.cursor, in: session.day) {
                    WatchRoundMovements(group: group)
                }
            }
            .frame(maxHeight: .infinity)

            if pastCap {
                Text("Past cap (\(SessionMath.formatElapsed(state.capSeconds)))")
                    .font(.fbb.label)
                    .foregroundStyle(Color.fbbStop)
            } else {
                Text("Cap left: \(SessionMath.formatElapsed(cappedRemaining))")
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
            }

            Button {
                playHaptic(.success)
                session.finishForTime()
            } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.fbbPrimary)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
    }
}
