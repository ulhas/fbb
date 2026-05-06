import SwiftUI

struct WorkoutHeroCard: View {
    let day: ParsedDay
    let track: TrainingWeekTrackIndexRow
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(track.displayName)
                    .font(.fbb.caption)
                    .foregroundStyle(.inkMuted)
                Spacer()
                Text(day.displayName)
                    .font(.fbb.caption)
                    .foregroundStyle(.inkMuted)
                    .lineLimit(1)
            }

            Text(headline)
                .font(.fbb.title2)
                .foregroundStyle(.inkPrimary)
                .multilineTextAlignment(.leading)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(day.sections) { section in
                    SectionRow(section: section)
                }
            }

            Button("Start Workout", action: onStart)
                .buttonStyle(PrimaryGlassButtonStyle())
                .padding(.top, Spacing.xs)
                .accessibilityHint("Begins logging today's workout")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private var headline: String {
        if day.sections.count <= 1, let first = day.sections.first {
            return first.displayName
        }
        return day.displayName
    }
}

private struct SectionRow: View {
    let section: ParsedSection

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(section.letter)
                .font(.fbb.title3)
                .foregroundStyle(.fbbOrange)
                .frame(width: 24, alignment: .leading)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(section.displayName)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(.inkPrimary)

                HStack(spacing: Spacing.xs) {
                    PrescriptionBadge(
                        mode: section.prescriptionMode,
                        durationMin: section.targetDurationMin,
                        durationMax: section.targetDurationMax
                    )
                    Text("\(exerciseCount) exercises")
                        .font(.fbb.caption)
                        .foregroundStyle(.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var exerciseCount: Int {
        section.groups.reduce(0) { $0 + $1.exercises.count }
    }
}
