import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// continuous_effort — open-ended stopwatch. User finishes the block when
/// they're done; no auto-stop.
struct WatchStopwatchCard: View {
    let session: WorkoutSession
    let state: StopwatchState

    var body: some View {
        let _ = session.tickCounter
        let elapsed = state.elapsedSeconds(now: Date())

        VStack(spacing: Spacing.xxs) {
            WatchModeTopBar(session: session, modeLabel: "Continuous")

            Spacer(minLength: 0)
            Text(SessionMath.formatElapsed(elapsed))
                .font(.fbb.metricLarge)
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)

            if let group = CursorAdvance.currentGroup(session.cursor, in: session.day) {
                WatchRoundMovements(group: group)
            }

            Button {
                playHaptic(.stop)
                session.skipToNextGroup()
            } label: {
                Label("End block", systemImage: "flag.checkered")
            }
            .buttonStyle(.fbbPrimary)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
    }
}
