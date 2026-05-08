import SwiftUI

/// Single-exercise group rendering. One card containing all sets stacked
/// as rows: "Front Squat" header → Set 1 row, Set 2 row, Set 3 row.
/// Reads as a unified "block of work on this movement", which is how
/// trainees mentally chunk single-exercise sets. Round-major rendering
/// is reserved for supersets (groups with > 1 exercise).
struct ExerciseMajorGroupCard: View {
    let section: ParsedSection
    let group: ParsedGroup
    let exercise: ParsedExercise
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, set in
                if idx > 0 {
                    Divider().padding(.leading, Spacing.md)
                }
                SetEntryRowCompact(
                    section: section,
                    group: group,
                    exercise: exercise,
                    set: set,
                    session: session
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }

            // Last-set rest prompt / inline rest, if any
            if let prescribedRest = lastSetRestSeconds, prescribedRest > 0 {
                Divider().padding(.leading, Spacing.md)
                if let rest = activeInlineRest {
                    InlineRestRow(rest: rest, session: session)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                } else {
                    RestPromptRow(seconds: prescribedRest) {
                        session.triggerInlineRest(
                            groupId: GroupId(section: section.position, group: group.position),
                            afterExercisePosition: exercise.position,
                            plannedSeconds: prescribedRest
                        )
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(exercise.movementDisplayName)
                .font(.byow.title3)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if exercise.sets.count > 1 {
                MarkAllCompleteButton(action: completeAllSets)
            }
        }
    }

    private var lastSetRestSeconds: Int? {
        guard let last = exercise.sets.last else { return nil }
        return SessionMath.midpoint(
            min: last.restAfterSecondsMin,
            max: last.restAfterSecondsMax
        )
    }

    private var activeInlineRest: InlineRestState? {
        let groupId = GroupId(section: section.position, group: group.position)
        return session.inlineRests.first {
            $0.groupId == groupId && $0.afterExercisePosition == exercise.position
        }
    }

    private func completeAllSets() {
        let now = Date()
        for set in exercise.sets {
            let setId = SetId(
                section: section.position,
                group: group.position,
                exercise: exercise.position,
                set: set.position
            )
            if session.setLog.contains(where: { $0.setId == setId && $0.perSide != .firstSide }) {
                continue
            }
            let actualReps: Int? = {
                if set.repsKind == "time" {
                    return SessionMath.midpoint(min: set.durationSecondsMin, max: set.durationSecondsMax)
                }
                return SessionMath.midpoint(min: set.repsMin, max: set.repsMax)
            }()
            session.setLog.append(SetLogEntry(
                id: UUID(),
                setId: setId,
                perSide: set.perSide ? .done : nil,
                outcome: .completed,
                completedAt: now,
                actualReps: actualReps,
                actualWeightKg: nil,
                actualRpe: nil,
                restTakenSeconds: nil
            ))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

/// Compact variant of SetEntryRow used inside ExerciseMajorGroupCard.
/// Lead column is "Set N" instead of the exercise name (which is in the
/// card header). Otherwise the row is the same logic — variants by
/// repsKind + perSide.
struct SetEntryRowCompact: View {
    let section: ParsedSection
    let group: ParsedGroup
    let exercise: ParsedExercise
    let set: ParsedSet
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set \(set.position)")
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                if let tempo = set.tempo, !tempo.isEmpty {
                    Text("@\(tempo)")
                        .font(.byow.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .monospaced()
                }
            }
            .frame(width: 60, alignment: .leading)

            // Reuse SetEntryRow — its internal "header" is the exercise
            // name though, which we don't want here. Instead, render the
            // rep/weight body directly via a wrapper that suppresses
            // its header.
            SetEntryBody(
                section: section,
                group: group,
                exercise: exercise,
                set: set,
                session: session
            )
        }
    }
}
