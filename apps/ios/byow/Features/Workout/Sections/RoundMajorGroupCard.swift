import SwiftUI

/// Round-major rendering of a group: outer iteration is rounds (Set 1,
/// Set 2, …), inner iteration is exercises. This matches how trainees
/// actually move through a superset/giant set: do all exercises once,
/// then again. Single-exercise groups still use this layout — "Set 1:
/// Back Squat — 8 reps × ___ kg ☐" reads cleanly too.
///
/// Visual: when the group has more than one exercise, a vertical orange
/// accent bar marks the chained-exercise band.
struct RoundMajorGroupCard: View {
    let section: ParsedSection
    let group: ParsedGroup
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            groupHeader
            ForEach(roundPositions, id: \.self) { round in
                roundBlock(round: round)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var groupHeader: some View {
        let label = headerLabel
        if !label.isEmpty {
            HStack(spacing: Spacing.xs) {
                if isSuperset {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.byowOrange)
                }
                Text(label)
                    .font(.byow.label).tracking(0.8)
                    .foregroundStyle(Color.byowOrange)
                Spacer(minLength: 0)
                if let note = group.loadingNote, !note.isEmpty {
                    Text(note)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var headerLabel: String {
        let mode = group.prescriptionMode
        let rounds = roundPositions.count
        switch mode {
        case "amrap":
            if let cap = group.capSeconds {
                return "AMRAP · \(cap / 60) MIN"
            }
            return "AMRAP"
        case "for_time": return "FOR TIME"
        case "tabata":   return "TABATA · 8 ROUNDS"
        case "emom":     return "EMOM · \(rounds) MIN"
        case "e2mom":    return "E2MOM · \(rounds * 2) MIN"
        case "e3mom":    return "E3MOM · \(rounds * 3) MIN"
        case "every_x_minutes":
            let interval = group.intervalSeconds ?? 60
            return "EVERY \(interval / 60) MIN · \(rounds) ROUNDS"
        case "rounds":
            if isSuperset { return "SUPERSET ~ \(rounds) ROUNDS" }
            return "\(rounds) ROUNDS"
        case "interval_pyramid": return "PYRAMID"
        case "continuous_effort": return "STEADY"
        default:
            if isSuperset {
                return rounds > 1 ? "SUPERSET ~ \(rounds) ROUNDS" : "SUPERSET"
            }
            return ""
        }
    }

    private var isSuperset: Bool {
        group.exercises.count > 1
    }

    /// Maximum number of sets across all exercises in the group → that's
    /// the round count. Most plans align all exercises to the same set
    /// count; if they don't, we render the union.
    private var roundPositions: [Int] {
        let positions = Set(group.exercises.flatMap { $0.sets.map(\.position) })
        return positions.sorted()
    }

    // MARK: - Round block

    @ViewBuilder
    private func roundBlock(round: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Set \(round)")
                    .font(.byow.title3)
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 0)
                MarkAllCompleteButton {
                    session.markRoundComplete(round: round)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)

            HStack(spacing: 0) {
                if isSuperset {
                    Rectangle()
                        .fill(Color.byowOrange)
                        .frame(width: 3)
                }
                VStack(alignment: .leading, spacing: 0) {
                    // id: \.offset because group.exercises positions
                    // are *not* always unique at runtime (alternates,
                    // re-parsed plans). Offset within an enumerated
                    // array is always unique.
                    ForEach(Array(group.exercises.enumerated()), id: \.offset) { index, exercise in
                        if let set = exercise.sets.first(where: { $0.position == round }) {
                            SetEntryRow(
                                section: section,
                                group: group,
                                exercise: exercise,
                                set: set,
                                session: session
                            )
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            if index < group.exercises.count - 1 {
                                Divider().padding(.leading, Spacing.md)
                            }
                        }
                        // Inline rest row attached to this exercise (after-position).
                        if let rest = inlineRest(for: exercise.position) {
                            InlineRestRow(rest: rest, session: session)
                                .padding(.horizontal, Spacing.md)
                                .padding(.bottom, Spacing.xs)
                        } else if let prescribedRest = prescribedRestSeconds(for: exercise),
                                  prescribedRest > 0,
                                  index < group.exercises.count - 1 {
                            RestPromptRow(
                                seconds: prescribedRest,
                                onStart: {
                                    session.triggerInlineRest(
                                        groupId: GroupId(section: section.position, group: group.position),
                                        afterExercisePosition: exercise.position,
                                        plannedSeconds: prescribedRest
                                    )
                                }
                            )
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.xs)
                        }
                    }
                }
            }
        }
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardCorner)
                .strokeBorder(Color.inkMuted.opacity(0.12), lineWidth: 1)
        )
    }

    private func inlineRest(for afterPosition: Int) -> InlineRestState? {
        let groupId = GroupId(section: section.position, group: group.position)
        return session.inlineRests.first {
            $0.groupId == groupId && $0.afterExercisePosition == afterPosition
        }
    }

    private func prescribedRestSeconds(for exercise: ParsedExercise) -> Int? {
        // Honor exercise-level rest if present, otherwise fall back to
        // the last set's rest. Suppress for chained-into-next exercises.
        if exercise.chainedIntoNext { return nil }
        if let mid = SessionMath.midpoint(
            min: exercise.restAfterSecondsMin,
            max: exercise.restAfterSecondsMax
        ), mid > 0 {
            return mid
        }
        if let last = exercise.sets.last,
           let mid = SessionMath.midpoint(
               min: last.restAfterSecondsMin,
               max: last.restAfterSecondsMax
           ), mid > 0 {
            return mid
        }
        return nil
    }
}
