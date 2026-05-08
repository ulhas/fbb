import SwiftUI

/// One-card-per-track summary of a single day's workout. Stacked vertically
/// on the Today screen so a user following multiple tracks sees all of
/// today's sessions at a glance. Tapping the card navigates to the
/// per-day detail (start / stop / timers land there in a later turn).
struct TrackWorkoutCard: View {
    let cell: TrainingWeekDayCellRow
    let onTap: () -> Void

    var body: some View {
        // Plain view — no Button wrapper. The call site wraps this in a
        // NavigationLink and applies PressedScaleButtonStyle there. A
        // nested Button would intercept the tap and the link wouldn't
        // route.
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header

            if cell.day.kind == .rest {
                restBody
            } else {
                workoutBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner)
                .strokeBorder(borderTint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint("Opens today's workout for \(cell.track.displayName)")
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: familySymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(familyTint)
                .frame(width: 30, height: 30)
                .background(familyTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(cell.track.displayName)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                if let cadenceLabel {
                    Text(cadenceLabel.uppercased())
                        .font(.byow.label).tracking(0.8)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            Spacer(minLength: Spacing.xs)

            kindPill
        }
    }

    private var workoutBody: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Day title intentionally omitted — for the parsed BYOW tracks
            // it almost always duplicates the track name in the header.
            // If a track ever ships day-specific titles (e.g. "Lower Day 1")
            // the header is still the right place; we'd surface it as a
            // subtitle in the header row instead of repeating it here.

            if !visibleSections.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleSections, id: \.position) { section in
                        SectionLine(section: section)
                    }
                    if hiddenSectionCount > 0 {
                        Text("+ \(hiddenSectionCount) more")
                            .font(.byow.caption.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }

            footerRow
        }
    }

    private var restBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rest day")
                .font(.byow.title3)
                .foregroundStyle(Color.inkPrimary)
            Text("Walk, sleep, hydrate. Logging is paused — pick it back up tomorrow.")
                .font(.byow.caption)
                .foregroundStyle(Color.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerRow: some View {
        HStack(spacing: Spacing.xs) {
            if let durationLabel {
                Label(durationLabel, systemImage: "clock.fill")
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .labelStyle(.titleAndIcon)
            }
            if exerciseCount > 0 {
                Label("\(exerciseCount) exercises", systemImage: "list.bullet")
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("Open")
                    .font(.byow.caption.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.byowOrange)
        }
    }

    // MARK: - Variants

    private var kindPill: some View {
        Text(kindLabel.uppercased())
            .font(.byow.label).tracking(0.6)
            .foregroundStyle(kindLabelTint)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(kindLabelBackground, in: Capsule())
    }

    private var kindLabel: String {
        switch cell.day.kind {
        case .rest:           return "Rest"
        case .workout:        return "Workout"
        case .activeRecovery: return "Recovery"
        case .mobility:       return "Mobility"
        case .lesson:         return "Lesson"
        }
    }

    private var kindLabelTint: Color {
        switch cell.day.kind {
        case .rest:    return .inkSecondary
        case .workout: return .byowOrange
        default:       return .byowTeal
        }
    }

    private var kindLabelBackground: Color {
        switch cell.day.kind {
        case .rest:    return .inkMuted.opacity(0.18)
        case .workout: return .byowOrangeTint.opacity(0.55)
        default:       return .byowTealTint.opacity(0.55)
        }
    }

    // MARK: - Computed

    private var visibleSections: [ParsedSection] {
        Array(cell.day.sections.prefix(3))
    }

    private var hiddenSectionCount: Int {
        max(0, cell.day.sections.count - visibleSections.count)
    }

    private var exerciseCount: Int {
        cell.day.sections.flatMap(\.groups).flatMap(\.exercises).count
    }

    private var durationLabel: String? {
        let mins = cell.day.sections.compactMap { $0.targetDurationMax ?? $0.targetDurationMin }
        guard !mins.isEmpty else { return nil }
        let total = mins.reduce(0, +)
        return total > 0 ? "\(total) min" : nil
    }

    private var cadenceLabel: String? {
        cell.track.cadence?.rawValue
    }

    private var cardBackground: Color {
        cell.day.kind == .rest ? Color.surfaceCard.opacity(0.85) : Color.surfaceCard
    }

    private var borderTint: Color {
        cell.day.kind == .rest ? Color.inkMuted : familyTint
    }

    private var familyTint: Color {
        switch cell.track.family {
        case .pumpLift, .perform:                          return .byowOrange
        case .pumpCondition, .hybridRunning, .minimalist:  return .byowTeal
        case .workshop, .onramp:                           return .inkMuted
        }
    }

    private var familySymbol: String {
        switch cell.track.family {
        case .pumpLift:      return "dumbbell.fill"
        case .pumpCondition: return "wind"
        case .perform:       return "flame.fill"
        case .minimalist:    return "circle.dashed"
        case .hybridRunning: return "figure.run"
        case .workshop:      return "wrench.and.screwdriver.fill"
        case .onramp:        return "arrow.up.right"
        }
    }

    private var a11yLabel: String {
        var parts: [String] = [
            cell.track.displayName,
            cell.day.displayName,
            kindLabel,
        ]
        if exerciseCount > 0 { parts.append("\(exerciseCount) exercises") }
        if let durationLabel { parts.append(durationLabel) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Section line

private struct SectionLine: View {
    let section: ParsedSection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(section.letter)
                .font(.byow.caption.weight(.bold))
                .foregroundStyle(Color.byowOrange)
                .frame(width: 16, alignment: .leading)
            Text(section.displayName)
                .font(.byow.caption.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            if exerciseCount > 0 {
                Text("\(exerciseCount)")
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkMuted)
                    .monospacedDigit()
            }
        }
    }

    private var exerciseCount: Int {
        section.groups.flatMap(\.exercises).count
    }
}

// MARK: - Press scale style

struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy, value: configuration.isPressed)
    }
}
