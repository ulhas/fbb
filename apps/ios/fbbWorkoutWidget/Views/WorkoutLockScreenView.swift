import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.trackDisplayName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                    Text(attributes.workoutTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                ElapsedTimerLabel(state: state)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(state.currentExerciseName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(state.setProgressLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let restEndsAt = state.restEndsAt {
                RestPill(restEndsAt: restEndsAt)
            } else if let mode = state.groupModeLabel {
                Text(mode)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            ProgressBar(completed: state.setsCompleted, total: state.setsTotal)

            HStack(spacing: 10) {
                Button(intent: PauseWorkoutIntent()) {
                    Label(state.pausedAt == nil ? "Pause" : "Resume",
                          systemImage: state.pausedAt == nil ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(intent: LogSetIntent()) {
                    Label("Log Set", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(14)
    }
}

struct ElapsedTimerLabel: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        if let pausedAt = state.pausedAt {
            // Frozen — render the elapsed at the moment of pause as a
            // static label. `Text(timerInterval:pauseTime:)` could do
            // this but on some OS versions it shows "00:00" the instant
            // pauseTime is non-nil; an explicit static label is safer.
            Text(formatElapsed(state.timerStart, until: pausedAt))
        } else {
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
        }
    }

    private func formatElapsed(_ start: Date, until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

struct RestPill: View {
    let restEndsAt: Date
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
            Text("Rest")
            Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.blue.opacity(0.35), in: Capsule())
    }
}

struct ProgressBar: View {
    let completed: Int
    let total: Int
    var body: some View {
        let fraction = total > 0 ? min(1.0, Double(completed) / Double(total)) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(.orange).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}
