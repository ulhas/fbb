import SwiftUI

/// Shared body for both SetEntryRow (round-major) and SetEntryRowCompact
/// (exercise-major). Picks one of four variants by repsKind + perSide:
///   - duration timer (with Start/Stop/Log)
///   - per-side L/R rows
///   - reps × weight
///   - free-form completion
///
/// State (text fields, focus) lives here; the wrapping row contributes a
/// header (exercise name or "Set N") above this body.
struct SetEntryBody: View {
    let section: ParsedSection
    let group: ParsedGroup
    let exercise: ParsedExercise
    let set: ParsedSet
    let session: WorkoutSession

    @State private var actualReps: String = ""
    @State private var actualWeight: String = ""
    @State private var leftReps: String = ""
    @State private var leftWeight: String = ""
    @State private var rightReps: String = ""
    @State private var rightWeight: String = ""
    @FocusState private var focused: Field?

    enum Field: Hashable {
        case reps, weight, leftReps, leftWeight, rightReps, rightWeight
    }

    var body: some View {
        Group {
            switch variant {
            case .duration: durationVariant
            case .perSide:  perSideVariant
            case .reps:     repsVariant
            case .free:     freeVariant
            }
        }
        // Single keyboard accessory declared at the top level. Mounting
        // it conditionally on `focused != nil` (the previous shape)
        // caused Auto Layout to thrash on every focus transition with
        // _UIRemoteKeyboardPlaceholderView vs _UIKBCompatInputView
        // constraint conflicts. The system only surfaces the toolbar
        // when a TextField is actually focused, so the declaration
        // being unconditional is a no-op when no input is active.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
        }
    }

    // MARK: - Variants

    @ViewBuilder
    private var durationVariant: some View {
        let setId = currentSetId
        let plannedSeconds = SessionMath.midpoint(
            min: set.durationSecondsMin,
            max: set.durationSecondsMax
        ) ?? 0
        let timer = session.exerciseTimers[setId]
        let logged = isLogged

        HStack(alignment: .center, spacing: Spacing.sm) {
            Text("\(plannedSeconds) sec")
                .font(.byow.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
            // Action cluster: ring-as-button + completion check, tightly
            // grouped so the user's eye reads "this is the timer
            // control" as one unit.
            HStack(spacing: Spacing.xs) {
                DurationTimerButton(
                    plannedSeconds: plannedSeconds,
                    timer: timer,
                    logged: logged,
                    onTap: { handleTimerTap(setId: setId, plannedSeconds: plannedSeconds, timer: timer, logged: logged) }
                )
                .frame(width: 56, height: 56)
                Button(action: { logSetCompletion(setId: setId, plannedSeconds: plannedSeconds, timer: timer, logged: logged) }) {
                    CompletionTapTarget(isLogged: logged, isCursor: isCursor)
                }
                .buttonStyle(.plain)
                .disabled(logged)
            }
        }
    }

    private func handleTimerTap(
        setId: SetId,
        plannedSeconds: Int,
        timer: ExerciseTimerState?,
        logged: Bool
    ) {
        if logged { return }
        if timer?.isCompleted == true {
            session.completeDurationSet(setId: setId)
        } else if timer?.isRunning == true {
            session.cancelExerciseTimer(setId: setId)
        } else {
            session.startExerciseTimer(setId: setId, plannedSeconds: plannedSeconds)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func logSetCompletion(
        setId: SetId,
        plannedSeconds: Int,
        timer: ExerciseTimerState?,
        logged: Bool
    ) {
        if logged { return }
        if timer?.isCompleted == true {
            session.completeDurationSet(setId: setId)
        } else {
            // Tap the check before timer ran = log directly with the
            // prescribed duration as the "actualReps" payload.
            let entry = SetEntry(
                outcome: .completed,
                actualReps: plannedSeconds,
                actualWeightKg: nil,
                actualRpe: nil
            )
            if session.cursor.setId == setId {
                session.completeSet(entry)
            } else {
                session.setLog.append(SetLogEntry(
                    id: UUID(), setId: setId, perSide: nil,
                    outcome: .completed, completedAt: Date(),
                    actualReps: plannedSeconds, actualWeightKg: nil,
                    actualRpe: nil, restTakenSeconds: nil
                ))
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @ViewBuilder
    private var perSideVariant: some View {
        let logged = isLogged
        VStack(spacing: 6) {
            HStack {
                Text(repsPrescriptionLabel)
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                Spacer(minLength: 0)
            }
            sideRow(label: "L", reps: $leftReps, weight: $leftWeight, repsField: .leftReps, weightField: .leftWeight, showCheck: false)
            HStack(spacing: Spacing.xs) {
                sideRow(label: "R", reps: $rightReps, weight: $rightWeight, repsField: .rightReps, weightField: .rightWeight, showCheck: false)
            }
            HStack {
                Spacer(minLength: 0)
                Button(action: completePerSide) {
                    CompletionTapTarget(isLogged: logged, isCursor: isCursor)
                }
                .buttonStyle(.plain)
                .disabled(logged)
            }
        }
    }

    @ViewBuilder
    private func sideRow(
        label: String,
        reps: Binding<String>,
        weight: Binding<String>,
        repsField: Field,
        weightField: Field,
        showCheck: Bool
    ) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.byow.bodyBold)
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 18)
            numericField(value: reps, placeholder: repsPlaceholder, field: repsField, kind: .reps, width: 70)
            Text("×")
                .font(.byow.caption)
                .foregroundStyle(Color.inkMuted)
            if shouldHideWeight {
                Text(weightPrescriptionLabel)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                numericField(value: weight, placeholder: "", field: weightField, kind: .weight, width: 80)
                Text(session.weightUnit.displayLabel.uppercased())
                    .font(.byow.label).tracking(0.6)
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var repsVariant: some View {
        let logged = isLogged
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 6) {
                Text(repsPrescriptionLabel)
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                HStack(spacing: Spacing.xs) {
                    numericField(value: $actualReps, placeholder: repsPlaceholder, field: .reps, kind: .reps, width: 70)
                    Text("REPS")
                        .font(.byow.label).tracking(0.6)
                        .foregroundStyle(Color.inkSecondary)
                    Text("×")
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkMuted)
                    if shouldHideWeight {
                        Text(weightPrescriptionLabel)
                            .font(.byow.bodyBold)
                            .foregroundStyle(Color.inkSecondary)
                    } else {
                        numericField(value: $actualWeight, placeholder: "", field: .weight, kind: .weight, width: 80)
                        Text(session.weightUnit.displayLabel.uppercased())
                            .font(.byow.label).tracking(0.6)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: completeReps) {
                CompletionTapTarget(isLogged: logged, isCursor: isCursor)
            }
            .buttonStyle(.plain)
            .disabled(logged)
        }
    }

    @ViewBuilder
    private var freeVariant: some View {
        let logged = isLogged
        HStack {
            Text(set.repsText ?? "Complete")
                .font(.byow.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
            Button {
                let entry = SetEntry(outcome: .completed, actualReps: nil, actualWeightKg: nil, actualRpe: nil)
                if session.cursor.setId == currentSetId {
                    session.completeSet(entry)
                } else {
                    session.setLog.append(SetLogEntry(
                        id: UUID(), setId: currentSetId, perSide: nil,
                        outcome: .completed, completedAt: Date(),
                        actualReps: nil, actualWeightKg: nil, actualRpe: nil,
                        restTakenSeconds: nil
                    ))
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                CompletionTapTarget(isLogged: logged, isCursor: isCursor)
            }
            .buttonStyle(.plain)
            .disabled(logged)
        }
    }

    // MARK: - Completion logic

    private func completeReps() {
        focused = nil
        let entry = SetEntry(
            outcome: .completed,
            actualReps: Int(actualReps) ?? defaultReps,
            actualWeightKg: parsedKg(actualWeight) ?? defaultWeightKg,
            actualRpe: nil
        )
        if session.cursor.setId == currentSetId {
            session.completeSet(entry)
        } else {
            session.setLog.append(SetLogEntry(
                id: UUID(), setId: currentSetId, perSide: nil,
                outcome: .completed, completedAt: Date(),
                actualReps: entry.actualReps, actualWeightKg: entry.actualWeightKg,
                actualRpe: nil, restTakenSeconds: nil
            ))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        actualReps = ""
        actualWeight = ""
    }

    private func completePerSide() {
        focused = nil
        let leftEntry = SetEntry(
            outcome: .completed,
            actualReps: Int(leftReps) ?? defaultReps,
            actualWeightKg: parsedKg(leftWeight) ?? defaultWeightKg,
            actualRpe: nil
        )
        let rightEntry = SetEntry(
            outcome: .completed,
            actualReps: Int(rightReps) ?? defaultReps,
            actualWeightKg: parsedKg(rightWeight) ?? defaultWeightKg,
            actualRpe: nil
        )
        if session.cursor.setId == currentSetId {
            session.completeSet(leftEntry)
            session.completeSet(rightEntry)
        } else {
            session.setLog.append(SetLogEntry(
                id: UUID(), setId: currentSetId, perSide: .firstSide,
                outcome: .completed, completedAt: Date(),
                actualReps: leftEntry.actualReps, actualWeightKg: leftEntry.actualWeightKg,
                actualRpe: nil, restTakenSeconds: nil
            ))
            session.setLog.append(SetLogEntry(
                id: UUID(), setId: currentSetId, perSide: .done,
                outcome: .completed, completedAt: Date(),
                actualReps: rightEntry.actualReps, actualWeightKg: rightEntry.actualWeightKg,
                actualRpe: nil, restTakenSeconds: nil
            ))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        leftReps = ""; leftWeight = ""
        rightReps = ""; rightWeight = ""
    }

    // MARK: - Helpers

    private enum Variant { case duration, perSide, reps, free }

    private var variant: Variant {
        if set.repsKind == "time" || set.repsKind == "per_side_time" { return .duration }
        if set.perSide { return .perSide }
        if set.repsKind == "max_unbroken" || set.repsKind == "complex_unit" { return .free }
        return .reps
    }

    private var currentSetId: SetId {
        SetId(
            section: section.position,
            group: group.position,
            exercise: exercise.position,
            set: set.position
        )
    }

    private var isLogged: Bool {
        session.setLog.contains { entry in
            entry.setId == currentSetId && entry.perSide != .firstSide
        }
    }

    private var isCursor: Bool {
        session.cursor.setId == currentSetId
    }

    private var shouldHideWeight: Bool {
        if case .none = set.weightRef { return true }
        if case .bodyweight = set.weightRef { return true }
        return false
    }

    private var defaultReps: Int? {
        SessionMath.midpoint(min: set.repsMin, max: set.repsMax)
    }

    private var defaultWeightKg: Double? {
        if case let .absolute(male, _, _) = set.weightRef { return male }
        return nil
    }

    private func parsedKg(_ text: String) -> Double? {
        guard let value = Double(text) else { return nil }
        return WeightUnitFormatter.toKg(value: value, unit: session.weightUnit)
    }

    private var repsPlaceholder: String {
        defaultReps.map { "\($0)" } ?? ""
    }

    private var repsPrescriptionLabel: String {
        let suffix = set.perSide ? " (per side)" : ""
        if let text = set.repsText { return text + suffix }
        let core: String
        switch (set.repsMin, set.repsMax) {
        case let (min?, max?) where min == max: core = "\(min) reps"
        case let (min?, max?): core = "\(min)–\(max) reps"
        case let (min?, nil): core = "\(min) reps"
        case let (nil, max?): core = "\(max) reps"
        case (nil, nil): core = "—"
        }
        return core + suffix
    }

    private var weightPrescriptionLabel: String {
        switch set.weightRef {
        case .none: return "—"
        case .bodyweight: return "BW"
        case let .absolute(male, _, raw):
            if let raw, !raw.isEmpty { return raw }
            if let male { return WeightUnitFormatter.format(kg: male, unit: session.weightUnit) }
            return ""
        case .percentOfWorking(let pct): return "\(Int(pct))% wk"
        case .relativeToSet(let pos): return "= set \(pos)"
        case let .deltaFromSet(pos, delta, _): return "set \(pos) \(delta >= 0 ? "+" : "")\(Int(delta))%"
        case .assistanceMatchRepMax(let rm): return "\(rm)RM"
        }
    }

    private enum NumericKind { case reps, weight }

    @ViewBuilder
    private func numericField(
        value: Binding<String>,
        placeholder: String,
        field: Field,
        kind: NumericKind,
        width: CGFloat
    ) -> some View {
        TextField(placeholder, text: value)
            .keyboardType(kind == .reps ? .numberPad : .decimalPad)
            .focused($focused, equals: field)
            .font(.byow.bodyBold)
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: width)
            .background(Color.byowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.inkMuted.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Visual completion target. Three states:
///   - logged → solid teal with white check
///   - cursor row, unlogged → solid orange-tint fill + thick orange ring
///     (reads loudly as "tap me")
///   - off-cursor, unlogged → thin gray outline
struct CompletionTapTarget: View {
    let isLogged: Bool
    let isCursor: Bool

    var body: some View {
        Group {
            if isLogged {
                ZStack {
                    Circle().fill(Color.byowTeal)
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
            } else if isCursor {
                ZStack {
                    Circle().fill(Color.byowOrangeTint)
                    Circle().strokeBorder(Color.byowOrange, lineWidth: 3)
                }
            } else {
                Circle()
                    .strokeBorder(Color.inkMuted.opacity(0.55), lineWidth: 2)
            }
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
    }
}

/// Ring + icon-based duration timer button. The ring itself is the tap
/// target — the icon at the center flips through the timer's lifecycle:
/// `play.fill` (idle) → `stop.fill` (running, with countdown digits) →
/// `checkmark` (completed). Solid color on the ring conveys mode at a
/// glance: orange = action available, teal = done.
struct DurationTimerButton: View {
    let plannedSeconds: Int
    let timer: ExerciseTimerState?
    let logged: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                DurationTimerButtonContent(
                    plannedSeconds: plannedSeconds,
                    timer: timer,
                    logged: logged,
                    now: ctx.date
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(logged)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if logged { return "Set logged" }
        if timer?.isCompleted == true { return "Log completed timer" }
        if timer?.isRunning == true { return "Stop timer" }
        return "Start timer"
    }
}

private struct DurationTimerButtonContent: View {
    let plannedSeconds: Int
    let timer: ExerciseTimerState?
    let logged: Bool
    let now: Date

    var body: some View {
        let remaining: Int = {
            if let t = timer { return max(0, t.remainingSeconds(now: now)) }
            return plannedSeconds
        }()
        // Clamp to [0, 1]. Without this, an idle timer (remaining ==
        // plannedSeconds) returns 0 fine, but transient states during
        // resume-after-pause can briefly produce negative or >1 values
        // that crash Circle().trim with "Invalid frame dimension".
        let progress: Double = {
            guard plannedSeconds > 0 else { return 0 }
            let raw = Double(plannedSeconds - remaining) / Double(plannedSeconds)
            return min(1, max(0, raw))
        }()

        ZStack {
            Circle()
                .fill(faceColor)
            Circle()
                .stroke(trackColor, lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            centerContent(remaining: remaining)
        }
    }

    @ViewBuilder
    private func centerContent(remaining: Int) -> some View {
        if logged {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
        } else if timer?.isCompleted == true {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
        } else if timer?.isRunning == true {
            Text(SessionMath.formatElapsed(remaining))
                .font(.byow.bodyBold)
                .monospacedDigit()
                .foregroundStyle(.white)
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .offset(x: 1) // optical centering for play triangle
        }
    }

    private var faceColor: Color {
        if logged || timer?.isCompleted == true { return Color.byowTeal }
        if timer?.isRunning == true { return Color.byowOrange.opacity(0.92) }
        return Color.byowOrange
    }

    private var trackColor: Color {
        if logged || timer?.isCompleted == true { return Color.byowTeal.opacity(0.4) }
        return Color.white.opacity(0.35)
    }

    private var progressColor: Color {
        if logged || timer?.isCompleted == true { return Color.white }
        return Color.white
    }
}
