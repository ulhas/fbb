import SwiftUI
import WatchKit
import BYOWDesignSystem
import BYOWWorkoutKitCore

/// Interval pyramid: pre-scripted countdowns of varying durations. We show
/// the current step, intensity (if specified), and within-step countdown.
struct WatchPyramidCard: View {
    let session: WorkoutSession
    let state: PyramidState

    @State private var lastStepIndex: Int = -1

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let stepIdx = state.currentStepIndex(now: now)
        let remaining = max(0, state.stepRemainingSeconds(now: now))
        let isComplete = state.isComplete(now: now)

        VStack(spacing: Spacing.xxs) {
            WatchModeTopBar(session: session, modeLabel: "Pyramid")

            if isComplete {
                Text("DONE")
                    .font(.byow.title2)
                    .foregroundStyle(Color.byowOrange)
            } else if stepIdx < state.steps.count {
                let step = state.steps[stepIdx]
                let intensity = step.intensityPct.map { "@ \(Int($0))%" } ?? ""
                Text("Step \(stepIdx + 1) of \(state.steps.count) \(intensity)")
                    .font(.byow.label)
                    .foregroundStyle(Color.byowOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            WatchCountdownRing(
                remaining: isComplete ? 0 : remaining,
                total: stepIdx < state.steps.count ? state.steps[stepIdx].durationSeconds : 1,
                centerText: SessionMath.formatElapsed(remaining),
                trackColor: .byowTeal,
                size: 96,
                lineWidth: 6
            )

            if !isComplete, stepIdx < state.steps.count, let notes = state.steps[stepIdx].notes {
                Text(notes)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Button {
                playHaptic(.stop)
                session.skipToNextGroup()
            } label: {
                Label("End block", systemImage: "flag.checkered")
            }
            .buttonStyle(.byowSecondary)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
        .onChange(of: state.currentStepIndex(now: Date())) { _, new in
            if new != lastStepIndex && lastStepIndex >= 0 {
                playHaptic(.directionUp)
            }
            lastStepIndex = new
        }
    }
}
