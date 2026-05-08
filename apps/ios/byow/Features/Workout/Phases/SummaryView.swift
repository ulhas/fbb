import SwiftUI

/// Post-workout summary. Big total time, per-section breakdown, AMRAP /
/// for-time scores if any, and a notes input. Tap Save to POST.
struct SummaryView: View {
    @Bindable var session: WorkoutSession
    let trackDisplayName: String
    let isSaving: Bool
    let saveError: APIError?
    let onSave: () -> Void

    @FocusState private var notesFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                stats
                if !session.groupScores.isEmpty {
                    scoresList
                }
                notesField
                if let saveError {
                    Text(saveError.errorDescription ?? "Couldn't save workout")
                        .font(.byow.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                saveButton
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.byowBackground)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if notesFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { notesFocused = false }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trackDisplayName.uppercased())
                .font(.byow.label).tracking(0.8)
                .foregroundStyle(Color.byowOrange)
            Text(session.day.displayName)
                .font(.byow.title2)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
            Text(SessionMath.formatElapsed(session.totalElapsedSeconds()))
                .font(.byow.metricHero)
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, Spacing.xs)
        }
    }

    private var stats: some View {
        let completed = session.setLog.filter { $0.outcome == .completed }.count
        let skipped = session.setLog.filter { $0.outcome == .skipped }.count
        let total = session.day.sections
            .flatMap(\.groups).flatMap(\.exercises).flatMap(\.sets).count
        return HStack(spacing: Spacing.md) {
            StatTile(label: "SETS DONE", value: "\(completed)", subtitle: "of \(total)")
            StatTile(label: "SKIPPED", value: "\(skipped)", subtitle: nil)
            StatTile(
                label: "SECTIONS",
                value: "\(session.sectionTransitions.count)",
                subtitle: "of \(session.day.sections.count)"
            )
        }
    }

    private var scoresList: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("SCORES")
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
            ForEach(Array(session.groupScores.values), id: \.groupId) { score in
                HStack {
                    Text("Section \(score.groupId.section), Group \(score.groupId.group)")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer(minLength: 0)
                    Text(scoreSummary(score))
                        .font(.byow.bodyBold)
                        .foregroundStyle(Color.inkPrimary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("NOTES")
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
            TextField(
                "How did it feel?",
                text: $session.notes,
                axis: .vertical
            )
            .lineLimit(3...8)
            .focused($notesFocused)
            .padding(Spacing.sm)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCorner)
                    .strokeBorder(Color.inkMuted.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button(action: onSave) {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                }
                Text(isSaving ? "Saving…" : "Save workout")
            }
        }
        .buttonStyle(.primaryGlass)
        .disabled(isSaving)
    }

    private func scoreSummary(_ score: GroupScore) -> String {
        var parts: [String] = []
        if let rounds = score.rounds { parts.append("\(rounds) rounds") }
        if let reps = score.partialReps, reps > 0 { parts.append("+\(reps)") }
        if let finish = score.finishSeconds {
            parts.append(SessionMath.formatElapsed(finish))
        }
        if let total = score.totalReps {
            parts.append("\(total) reps")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.byow.label).tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
            Text(value)
                .font(.byow.metricLarge)
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkMuted)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
    }
}
