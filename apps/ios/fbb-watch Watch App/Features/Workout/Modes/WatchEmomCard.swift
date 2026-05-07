import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// EMOM-style mode (emom, e2mom, e3mom, every_x_minutes). Within-minute
/// countdown ring; auto-flips to next round at each tick boundary with a
/// strong haptic. Round counter shows "X of Y".
struct WatchEmomCard: View {
    let session: WorkoutSession
    let state: IntervalState

    @State private var lastRoundIndex: Int = -1

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let roundIdx = state.roundIndex(now: now)
        let withinRound = max(0, state.roundRemainingSeconds(now: now))
        let isComplete = state.isComplete(now: now)
        let displayedRound = min(roundIdx + 1, state.totalRounds)

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            WatchModeTopBar(
                session: session,
                modeLabel: "EMOM \(SessionMath.formatElapsed(state.intervalSeconds))"
            )

            VStack(spacing: Spacing.xxs) {
                Text(isComplete
                     ? "Done"
                     : "Round \(displayedRound) of \(state.totalRounds)")
                    .font(.fbb.label)
                    .foregroundStyle(Color.fbbOrange)

                WatchCountdownRing(
                    remaining: isComplete ? 0 : withinRound,
                    total: state.intervalSeconds,
                    centerText: SessionMath.formatElapsed(withinRound),
                    trackColor: .fbbTeal,
                    size: 96,
                    lineWidth: 5
                )
            }
            .frame(maxWidth: .infinity)

            if let group = CursorAdvance.currentGroup(session.cursor, in: session.day) {
                WatchRoundMovements(group: group)
            }

            Button {
                playHaptic(.stop)
                session.skipToNextGroup()
            } label: {
                Label("End block", systemImage: "flag.checkered")
            }
            .buttonStyle(.fbbSecondary)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
        .onChange(of: state.roundIndex(now: Date())) { _, new in
            // Strong haptic at each round boundary so the user knows it's
            // time for the next round even when they're not looking.
            if new != lastRoundIndex && lastRoundIndex >= 0 {
                playHaptic(.notification)
            }
            lastRoundIndex = new
        }
    }
}
