import SwiftUI
import WatchKit
import BYOWDesignSystem
import BYOWWorkoutKitCore

/// Tabata: 20s WORK / 10s REST × 8. Big work/rest text dominates so the
/// user can glance at their wrist mid-effort and know which phase they're in.
struct WatchTabataCard: View {
    let session: WorkoutSession
    let state: TabataState

    @State private var lastSubPhase: TabataState.SubPhase = .work

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let phase = state.subPhase(now: now)
        let remaining = max(0, state.subPhaseRemainingSeconds(now: now))
        let roundIdx = state.roundIndex(now: now)
        let isComplete = state.isComplete(now: now)
        let phaseTotal = phase == .work ? state.workSeconds : state.restSeconds
        let phaseColor: Color = phase == .work ? .byowOrange : .byowTeal

        VStack(spacing: Spacing.xxs) {
            WatchModeTopBar(session: session, modeLabel: "Tabata")

            Text(isComplete ? "DONE" : (phase == .work ? "WORK" : "REST"))
                .font(.byow.title2)
                .foregroundStyle(phaseColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(phaseColor.opacity(0.15), in: Capsule())

            WatchCountdownRing(
                remaining: isComplete ? 0 : remaining,
                total: phaseTotal,
                centerText: SessionMath.formatElapsed(remaining),
                trackColor: phaseColor,
                size: 92,
                lineWidth: 6
            )

            Text(isComplete
                 ? "All \(state.totalRounds) rounds"
                 : "Round \(min(roundIdx + 1, state.totalRounds)) of \(state.totalRounds)")
                .font(.byow.label)
                .foregroundStyle(Color.inkMuted)

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
        .onChange(of: state.subPhase(now: Date())) { _, new in
            if new != lastSubPhase {
                playHaptic(.notification)
                lastSubPhase = new
            }
        }
    }
}
