import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct ExpandedLeadingView: View {
    let attributes: WorkoutActivityAttributes
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(attributes.trackDisplayName.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .lineLimit(1)
            Text(attributes.workoutTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}

struct ExpandedTrailingView: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        ElapsedTimerLabel(state: state)
            .font(.title3.monospacedDigit().weight(.semibold))
    }
}

struct ExpandedCenterView: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.currentExerciseName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(state.setProgressLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ExpandedBottomView: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 8) {
            if let restEndsAt = state.restEndsAt {
                RestPill(restEndsAt: restEndsAt)
            }
            Spacer()
            Button(intent: PauseWorkoutIntent()) {
                Image(systemName: state.pausedAt == nil ? "pause.fill" : "play.fill")
            }
            .tint(.white)
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(intent: LogSetIntent()) {
                Label("Log", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .tint(.orange)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

struct CompactTrailingView: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        if let restEndsAt = state.restEndsAt {
            Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(.blue)
        } else if state.pausedAt != nil {
            Image(systemName: "pause.fill").foregroundStyle(.orange)
        } else {
            ElapsedTimerLabel(state: state)
                .monospacedDigit()
                .foregroundStyle(.orange)
        }
    }
}
