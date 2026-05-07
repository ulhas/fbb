import SwiftUI

/// Pre-workout overview. Section headers in orange uppercase ("WARMUP",
/// "STRENGTH INTENSITY"); supersets get a "SUPERSET ~ N ROUNDS" header
/// and a vertical orange accent on grouped exercises. Mirrors the live
/// app's information hierarchy.
struct PreStartView: View {
    let session: WorkoutSession
    let trackDisplayName: String
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if let focus = focusContent {
                        focusBanner(title: focus.title, body: focus.body)
                    }

                    ForEach(workoutSections) { section in
                        sectionBlock(section: section)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, 120)
            }

            Button(action: onStart) {
                Text("Start workout")
            }
            .buttonStyle(.primaryGlass)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .navigationTitle("")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trackDisplayName.uppercased())
                .font(.fbb.label).tracking(0.8)
                .foregroundStyle(Color.fbbOrange)
            Text(session.day.displayName)
                .font(.fbb.display)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
            HStack(spacing: Spacing.sm) {
                if let total = totalTargetMinutes {
                    Label("\(total) min", systemImage: "clock.fill")
                        .font(.fbb.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .labelStyle(.titleAndIcon)
                }
                Label(
                    "\(workoutSections.count) \(workoutSections.count == 1 ? "section" : "sections")",
                    systemImage: "rectangle.stack.fill"
                )
                .font(.fbb.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .labelStyle(.titleAndIcon)
                Label(
                    "\(session.day.totalExercises) \(session.day.totalExercises == 1 ? "exercise" : "exercises")",
                    systemImage: "list.bullet"
                )
                .font(.fbb.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .labelStyle(.titleAndIcon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalTargetMinutes: Int? {
        // Only count workout-bearing sections; focus_note sections are
        // prose-only and don't contribute to elapsed time targets.
        let mins = workoutSections.compactMap { $0.targetDurationMax ?? $0.targetDurationMin }
        let sum = mins.reduce(0, +)
        return sum > 0 ? sum : nil
    }

    /// Sections we render as actual exercise blocks. We hide
    /// `focus_note`-kind sections — their prose is already surfaced by
    /// the focus banner at the top of the screen, and rendering them
    /// twice was the bug noted in #plan iteration. Same applies to
    /// `lesson` sections, which are video/content placeholders we don't
    /// drive the workout flow off of.
    private var workoutSections: [ParsedSection] {
        session.day.sections.filter { $0.kind != "focus_note" && $0.kind != "lesson" }
    }

    /// Pull the day's banner content. Prefer a `focus`-kind coaching
    /// note (the canonical FBB shape). Fall back to a `focus_note`
    /// section's prose if no coaching note exists. Returns nil if
    /// neither source has content.
    private var focusContent: (title: String, body: String)? {
        if let note = session.day.coachingNotes.first(where: { $0.kind == "focus" }) {
            return (note.title ?? "Focus", note.bodyMarkdown)
        }
        if let section = session.day.sections.first(where: { $0.kind == "focus_note" }) {
            if let body = section.dailyFocusNote, !body.isEmpty {
                return (section.displayName, body)
            }
        }
        return nil
    }

    private func focusBanner(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.fbb.label).tracking(0.6)
                .foregroundStyle(Color.fbbOrange)
            Text(body)
                .font(.fbb.body)
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.fbbOrangeTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
    }

    @ViewBuilder
    private func sectionBlock(section: ParsedSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(section.displayName.uppercased())
                    .font(.fbb.label).tracking(0.8)
                    .foregroundStyle(Color.fbbOrange)
                if let mins = section.targetDurationMax ?? section.targetDurationMin {
                    Text("· \(mins) min")
                        .font(.fbb.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: 0)
            }

            if let note = section.dailyFocusNote, !note.isEmpty {
                Text(note)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.groups) { group in
                groupPreview(section: section, group: group)
            }
        }
    }

    @ViewBuilder
    private func groupPreview(section: ParsedSection, group: ParsedGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header (superset / rounds / amrap-cap)
            let header = groupPreviewHeader(group: group)
            if !header.isEmpty {
                HStack(spacing: 6) {
                    if isSuperset(group) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.fbbOrange)
                    }
                    Text(header)
                        .font(.fbb.label).tracking(0.6)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)
            }

            HStack(spacing: 0) {
                if isSuperset(group) {
                    Rectangle()
                        .fill(Color.fbbOrange)
                        .frame(width: 3)
                        .clipShape(Capsule())
                        .padding(.trailing, Spacing.sm)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(group.exercises.enumerated()), id: \.offset) { idx, exercise in
                        exercisePreviewRow(exercise: exercise)
                        if idx < group.exercises.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            }
        }
    }

    private func groupPreviewHeader(group: ParsedGroup) -> String {
        let exCount = group.exercises.count
        let setsPerExercise = group.exercises.map { $0.sets.count }.max() ?? 0
        switch group.prescriptionMode {
        case "amrap":
            if let cap = group.capSeconds { return "AMRAP · \(cap / 60) MIN" }
            return "AMRAP"
        case "for_time": return "FOR TIME"
        case "tabata":   return "TABATA · 8 ROUNDS"
        case "emom":     return "EMOM · \(setsPerExercise) MIN"
        case "e2mom":    return "E2MOM · \(setsPerExercise * 2) MIN"
        case "e3mom":    return "E3MOM · \(setsPerExercise * 3) MIN"
        case "every_x_minutes":
            let interval = group.intervalSeconds ?? 60
            return "EVERY \(interval / 60) MIN · \(setsPerExercise) ROUNDS"
        case "rounds":
            if exCount > 1 { return "SUPERSET ~ \(setsPerExercise) ROUNDS" }
            return "\(setsPerExercise) ROUNDS"
        default:
            if exCount > 1 {
                return setsPerExercise > 1 ? "SUPERSET ~ \(setsPerExercise) ROUNDS" : "SUPERSET"
            }
            if setsPerExercise > 1 { return "\(setsPerExercise) SETS" }
            return ""
        }
    }

    private func isSuperset(_ group: ParsedGroup) -> Bool {
        group.exercises.count > 1
    }

    private func exercisePreviewRow(exercise: ParsedExercise) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.movementDisplayName)
                    .font(.fbb.body)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                if let summary = setsSummary(for: exercise) {
                    Text(summary)
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if exercise.chainedIntoNext {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.fbbOrange.opacity(0.8))
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func setsSummary(for exercise: ParsedExercise) -> String? {
        guard let first = exercise.sets.first else { return nil }
        let count = exercise.sets.count
        let reps: String
        if first.repsKind == "time" {
            if let mid = SessionMath.midpoint(min: first.durationSecondsMin, max: first.durationSecondsMax) {
                reps = "\(mid) sec"
            } else if let text = first.repsText {
                reps = text
            } else {
                reps = "Time"
            }
        } else {
            switch (first.repsMin, first.repsMax) {
            case let (min?, max?) where min == max: reps = "\(min) reps"
            case let (min?, max?): reps = "\(min)–\(max) reps"
            case let (min?, nil): reps = "\(min) reps"
            case let (nil, max?): reps = "\(max) reps"
            case (nil, nil): reps = first.repsText ?? ""
            }
        }
        let perSide = first.perSide ? " (per side)" : ""
        if count > 1 {
            return "\(count) × \(reps)\(perSide)"
        }
        return "\(reps)\(perSide)"
    }
}
