import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// AMRAP mode: counts down a cap, lets the user tap "+1 round" each time
/// they finish the round circuit. Crown also drives round count.
struct WatchAmrapCard: View {
    let session: WorkoutSession
    let state: CapState

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let remaining = max(0, state.remainingSeconds(now: now))
        let isExpired = state.isExpired(now: now)

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            WatchModeTopBar(session: session, modeLabel: "AMRAP \(SessionMath.formatElapsed(state.capSeconds))")

            HStack(spacing: Spacing.xs) {
                WatchCountdownRing(
                    remaining: remaining,
                    total: state.capSeconds,
                    centerText: SessionMath.formatElapsed(remaining),
                    trackColor: isExpired ? .fbbStop : .fbbOrange,
                    size: 88,
                    lineWidth: 5
                )
                if let group = CursorAdvance.currentGroup(session.cursor, in: session.day) {
                    WatchRoundMovements(group: group)
                }
            }
            .frame(maxHeight: .infinity)

            WatchIntStepper(
                label: "ROUNDS",
                value: state.userRoundsCompleted,
                onDecrement: { session.decrementGroupRound() },
                onIncrement: { session.incrementGroupRound() }
            )

            Button {
                playHaptic(.stop)
                session.skipToNextGroup()
            } label: {
                Label("Finish", systemImage: "flag.checkered")
            }
            .buttonStyle(.fbbPrimary)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
        .focusable()
        .digitalCrownRotation(
            Binding(
                get: { Double(state.userRoundsCompleted) },
                set: { newValue in
                    let target = max(0, Int(newValue))
                    let delta = target - state.userRoundsCompleted
                    if delta > 0 {
                        for _ in 0..<delta { session.incrementGroupRound() }
                    } else if delta < 0 {
                        for _ in 0..<(-delta) { session.decrementGroupRound() }
                    }
                }
            ),
            from: 0,
            through: 100,
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
}
