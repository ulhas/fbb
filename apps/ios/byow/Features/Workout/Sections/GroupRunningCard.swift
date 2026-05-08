import SwiftUI

/// One group's live UI in the running phase. Dispatches by group shape:
///
///   - **Multi-exercise group** (chained / superset): round-major card.
///     "Set 1: ExA, ExB, ExC" → "Set 2: ExA, ExB, ExC". Vertical orange
///     accent bar marks the chain.
///
///   - **Single-exercise group**: exercise-major card. One card with all
///     the exercise's sets stacked as rows. Reads as a unified block,
///     not a stack of disjoint Set 1 / Set 2 cards.
///
/// In both cases, time-driven group modes (EMOM/AMRAP/etc.) prepend a
/// per-mode banner with the live timer.
struct GroupRunningCard: View {
    let section: ParsedSection
    let group: ParsedGroup
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            modeBanner

            if isSingleExercise, let exercise = group.exercises.first {
                ExerciseMajorGroupCard(
                    section: section,
                    group: group,
                    exercise: exercise,
                    session: session
                )
            } else {
                RoundMajorGroupCard(
                    section: section,
                    group: group,
                    session: session
                )
            }
        }
        // No global opacity dim. The CompletionTapTarget cursor
        // indicator + active section header are enough — opacity on the
        // whole group washed out orange controls (Start button, Mark-
        // all pill) and made them look unclickable.
    }

    @ViewBuilder
    private var modeBanner: some View {
        switch group.prescriptionMode {
        case "emom", "e2mom", "e3mom", "every_x_minutes":
            IntervalBody(group: group, session: session, isActive: isActive)
        case "amrap", "for_time", "density":
            CapCountdownBody(group: group, session: session, isActive: isActive)
        case "tabata":
            TabataBody(group: group, session: session, isActive: isActive)
        case "interval_pyramid":
            PyramidBody(group: group, session: session, isActive: isActive)
        case "continuous_effort":
            StopwatchBody(group: group, session: session, isActive: isActive)
        default:
            EmptyView()
        }
    }

    private var isSingleExercise: Bool {
        group.exercises.count == 1
    }

    private var isActive: Bool {
        session.cursor.sectionPosition == section.position &&
        session.cursor.groupPosition == group.position
    }
}
