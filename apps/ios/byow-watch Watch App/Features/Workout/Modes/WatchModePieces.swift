import SwiftUI
import WatchKit
import BYOWDesignSystem
import BYOWWorkoutKitCore

/// Shared pieces used by every mode-specific Set card. Keeping them here
/// (instead of duplicated per file) means the modes stay visually
/// consistent — same section pill, same ring, same button corner radius.

/// Top context bar — section pill + mode label + total elapsed.
struct WatchModeTopBar: View {
    let session: WorkoutSession
    let modeLabel: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let section = CursorAdvance.currentSection(session.cursor, in: session.day) {
                Text(section.letter)
                    .font(.byow.label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.byowOrange, in: Capsule())
            }
            Text(modeLabel)
                .font(.byow.label)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .semibold))
                Text(SessionMath.formatElapsed(session.totalElapsedSeconds()))
                    .font(.byow.label)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.inkMuted)
        }
    }
}

/// Countdown ring with a center label. Used by AMRAP, EMOM, Tabata, Pyramid.
struct WatchCountdownRing: View {
    let remaining: Int
    let total: Int
    let centerText: String
    var trackColor: Color = .byowTeal
    var size: CGFloat = 110
    var lineWidth: CGFloat = 6

    var body: some View {
        let progress = max(0.0, min(1.0, Double(remaining) / Double(max(total, 1))))
        ZStack {
            Circle()
                .stroke(Color.inkMuted.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(centerText)
                .font(.byow.watchMetricHero)
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
    }
}

/// Stepper-style row used to increment / decrement integers (rounds,
/// partial reps, etc.). 44pt min height per button.
struct WatchIntStepper: View {
    let label: String
    let value: Int
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: { onDecrement(); haptic(.click) }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.surfaceCard, in: Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.byow.watchMetricHero)
                    .foregroundStyle(Color.byowOrange)
                    .monospacedDigit()
                Text(label)
                    .font(.byow.label)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity)

            Button(action: { onIncrement(); haptic(.success) }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.byowOrange, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}

/// Compact list of round movements. Each movement = first exercise's
/// movement display name. Truncates with minimumScaleFactor.
struct WatchRoundMovements: View {
    let group: ParsedGroup

    private var summary: String {
        // Render as "5 PU · 10 SQ · 15 SU" if reps + short name available,
        // else fall back to full names joined.
        let parts: [String] = group.exercises.compactMap { ex in
            guard let firstSet = ex.sets.first else { return nil }
            let short = ex.movementDisplayName.split(separator: " ").first.map(String.init) ?? ex.movementDisplayName
            if let reps = firstSet.repsMin ?? firstSet.repsMax {
                return "\(reps) \(short)"
            }
            return short
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Text(summary.isEmpty ? "—" : summary)
            .font(.byow.caption)
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func playHaptic(_ kind: WKHapticType) {
    WKInterfaceDevice.current().play(kind)
}
