import SwiftUI

// Banners for time-driven group modes. Just the live timer + status —
// the exercise list is rendered separately by `RoundMajorGroupCard`, so
// these don't duplicate it. Lumped into one file because each is small.

// MARK: - Interval (EMOM family + every_x_minutes)

struct IntervalBody: View {
    let group: ParsedGroup
    let session: WorkoutSession
    let isActive: Bool

    var body: some View {
        if isActive, case .interval(let state) = session.activeBlock {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let now = ctx.date
                let remaining = max(0, state.roundRemainingSeconds(now: now))
                let round = state.roundIndex(now: now) + 1
                modeBanner(
                    title: "ROUND \(min(round, state.totalRounds)) / \(state.totalRounds)",
                    valueLabel: SessionMath.formatElapsed(remaining),
                    valueColor: remaining <= 5 ? .red : Color.inkPrimary
                )
            }
        }
    }
}

// MARK: - Cap countdown (AMRAP / for_time / density)

struct CapCountdownBody: View {
    let group: ParsedGroup
    let session: WorkoutSession
    let isActive: Bool

    var body: some View {
        if isActive, case .capCountdown(let state) = session.activeBlock {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let remaining = state.remainingSeconds(now: ctx.date)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.prescriptionMode.uppercased().replacingOccurrences(of: "_", with: " "))
                            .font(.byow.label).tracking(0.6)
                            .foregroundStyle(Color.inkSecondary)
                        Text(SessionMath.formatCountdown(remaining))
                            .font(.byow.metricLarge)
                            .foregroundStyle(remaining <= 10 ? .red : Color.inkPrimary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    roundCounter(state: state)
                }
                .padding(Spacing.md)
                .background(Color.byowOrangeTint.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            }
        }
    }

    private func roundCounter(state: CapState) -> some View {
        VStack(spacing: Spacing.xs) {
            Text("ROUNDS")
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
            HStack(spacing: Spacing.xs) {
                Button { session.decrementGroupRound() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text("\(state.userRoundsCompleted)")
                    .font(.byow.metric)
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 30)
                Button { session.incrementGroupRound() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.byowOrange)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tabata

struct TabataBody: View {
    let group: ParsedGroup
    let session: WorkoutSession
    let isActive: Bool

    var body: some View {
        if isActive, case .tabata(let state) = session.activeBlock {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let now = ctx.date
                let phase = state.subPhase(now: now)
                let remaining = state.subPhaseRemainingSeconds(now: now)
                let round = state.roundIndex(now: now) + 1
                modeBanner(
                    title: "\(phase == .work ? "WORK" : "REST") · ROUND \(min(round, state.totalRounds)) / \(state.totalRounds)",
                    valueLabel: SessionMath.formatElapsed(remaining),
                    valueColor: phase == .work ? Color.byowOrange : Color.byowTeal
                )
            }
        }
    }
}

// MARK: - Pyramid

struct PyramidBody: View {
    let group: ParsedGroup
    let session: WorkoutSession
    let isActive: Bool

    var body: some View {
        if isActive, case .pyramid(let state) = session.activeBlock, !state.steps.isEmpty {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let now = ctx.date
                let idx = min(state.currentStepIndex(now: now), state.steps.count - 1)
                let remaining = state.stepRemainingSeconds(now: now)
                let step = state.steps[idx]
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP \(idx + 1) / \(state.steps.count)")
                        .font(.byow.label).tracking(0.6)
                        .foregroundStyle(Color.inkSecondary)
                    Text(SessionMath.formatElapsed(remaining))
                        .font(.byow.metricLarge)
                        .foregroundStyle(Color.inkPrimary)
                        .monospacedDigit()
                    if let intensity = step.intensityPct {
                        Text("\(Int(intensity))% intensity")
                            .font(.byow.caption.weight(.semibold))
                            .foregroundStyle(Color.byowOrange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(Color.byowOrangeTint.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            }
        }
    }
}

// MARK: - Stopwatch (continuous_effort)

struct StopwatchBody: View {
    let group: ParsedGroup
    let session: WorkoutSession
    let isActive: Bool

    var body: some View {
        if isActive, case .stopwatch(let state) = session.activeBlock {
            TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                let elapsed = state.elapsedSeconds(now: ctx.date)
                modeBanner(
                    title: "STEADY EFFORT",
                    valueLabel: SessionMath.formatElapsed(elapsed),
                    valueColor: Color.inkPrimary
                )
            }
        }
    }
}

// MARK: - Shared

private func modeBanner(title: String, valueLabel: String, valueColor: Color) -> some View {
    HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
            Text(valueLabel)
                .font(.byow.metricLarge)
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
        Spacer(minLength: 0)
    }
    .padding(Spacing.md)
    .background(Color.byowOrangeTint.opacity(0.4))
    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
}
