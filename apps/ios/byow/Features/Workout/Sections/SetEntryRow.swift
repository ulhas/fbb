import SwiftUI

/// One row in a round-major round block (Set N, exercise A/B/C…). The
/// header is the exercise name; the body delegates to `SetEntryBody`
/// which handles the time/reps/L+R/free variants.
///
/// In single-exercise groups we use `ExerciseMajorGroupCard` +
/// `SetEntryRowCompact` instead, where the header is "Set N" and the
/// exercise name lives at the card top.
struct SetEntryRow: View {
    let section: ParsedSection
    let group: ParsedGroup
    let exercise: ParsedExercise
    let set: ParsedSet
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(exercise.movementDisplayName)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                if exercise.chainedIntoNext {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.byowOrange)
                }
                Spacer(minLength: 0)
                if let tempo = set.tempo, !tempo.isEmpty {
                    Text("@\(tempo)")
                        .font(.byow.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .monospaced()
                }
            }

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
