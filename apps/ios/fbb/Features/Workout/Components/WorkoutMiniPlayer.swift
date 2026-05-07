import SwiftUI

/// Apple-Music-style mini player rendered in the TabView's bottom
/// accessory while a workout is in flight.
///
/// Two layouts:
///   - **expanded** (default): chip + section/exercise label + elapsed
///     + End + Pause/Resume. Sits above the tab bar.
///   - **inline**: a much tighter form for when iOS collapses the
///     accessory into the tab bar itself (e.g. during scroll). Just
///     the elapsed clock and the play/pause button.
///
/// `placement` is read from the SwiftUI environment; iOS chooses
/// between expanded and inline automatically based on context.
struct WorkoutMiniPlayer: View {
    let session: WorkoutSession
    let onTap: () -> Void
    let onEnd: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        switch placement {
        case .inline:
            inlineForm
        default:
            expandedForm
        }
    }

    // MARK: - Expanded

    private var expandedForm: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
            HStack(alignment: .center, spacing: Spacing.sm) {
                Button(action: onTap) {
                    HStack(alignment: .center, spacing: Spacing.sm) {
                        sectionChip
                        VStack(alignment: .leading, spacing: 2) {
                            Text(primaryLabel)
                                .font(.fbb.bodyBold)
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            Text(secondaryLabel(now: ctx.date))
                                .font(.fbb.caption)
                                .foregroundStyle(secondaryColor)
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                pauseButton(size: 40, iconSize: 16)
                stopButton(size: 40, iconSize: 14)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Inline

    private var inlineForm: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
            HStack(spacing: Spacing.xs) {
                Button(action: onTap) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.fbbOrange)
                        Text(SessionMath.formatElapsed(session.totalElapsedSeconds(now: ctx.date)))
                            .font(.fbb.bodyBold)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                pauseButton(size: 32, iconSize: 13)
                stopButton(size: 32, iconSize: 11)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Buttons

    /// Destructive end-of-workout control. Saturated red (`Color.fbbStop`
    /// asset) matched in punch to `Color.fbbOrange`, so the two
    /// playback buttons read as a single deliberate pair — same weight,
    /// different intent. Confirm dialog is presented from `RootView`.
    private func stopButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: onEnd) {
            Image(systemName: "stop.fill")
                .font(.system(size: iconSize, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.fbbStop)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End workout")
    }

    private func pauseButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button {
            if session.isPaused {
                session.resumeWorkout()
            } else {
                session.pauseWorkout()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: iconSize, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.fbbOrange)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isPaused ? "Resume workout" : "Pause workout")
    }

    // MARK: - Helpers

    private var sectionChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.fbbOrangeTint)
            Text(currentSectionLetter)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.fbbOrange)
        }
        .frame(width: 36, height: 36)
    }

    private var currentSectionLetter: String {
        CursorAdvance.currentSection(session.cursor, in: session.day)?.letter ?? "•"
    }

    private var primaryLabel: String {
        if let exercise = CursorAdvance.currentExercise(session.cursor, in: session.day) {
            return exercise.movementDisplayName
        }
        return session.day.displayName
    }

    private func secondaryLabel(now: Date) -> String {
        let elapsed = SessionMath.formatElapsed(session.totalElapsedSeconds(now: now))
        if session.isPaused {
            return "PAUSED · \(elapsed)"
        }
        if let section = CursorAdvance.currentSection(session.cursor, in: session.day) {
            return "\(section.displayName) · \(elapsed)"
        }
        return elapsed
    }

    private var secondaryColor: Color {
        session.isPaused ? Color.fbbOrange : Color.inkSecondary
    }
}
