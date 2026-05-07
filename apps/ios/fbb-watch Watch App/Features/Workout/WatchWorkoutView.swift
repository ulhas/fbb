import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// Active session screen. Paged TabView with three pages — Set / Rest /
/// Controls. Rest page is auto-presented when the engine reports a rest
/// state and auto-pops back to Set when the rest is dismissed.
struct WatchWorkoutView: View {
    @Environment(WatchAppEnvironment.self) private var env
    @Binding var path: NavigationPath
    @State private var pageIndex = 0

    var body: some View {
        if let session = env.store.activeSession {
            // Force re-render every tick so timers update.
            let _ = session.tickCounter

            TabView(selection: $pageIndex) {
                WatchModeRouter(session: session)
                    .tag(0)

                WatchRestRing(session: session)
                    .tag(1)

                WatchControlsView(
                    session: session,
                    onEnd: {
                        env.store.end()
                        path.append(WatchRoute.summary)
                    },
                    onAbandon: { reason in
                        session.abandonWorkout(reason: reason)
                        path.append(WatchRoute.summary)
                    }
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .navigationBarBackButtonHidden(true)
            .onChange(of: session.restAfter != nil) { _, isResting in
                withAnimation { pageIndex = isResting ? 1 : 0 }
            }
            .onChange(of: session.phase) { _, newPhase in
                if case .summary = newPhase {
                    path.append(WatchRoute.summary)
                }
                if case .abandoned = newPhase {
                    path.append(WatchRoute.summary)
                }
            }
        } else {
            // No active session — shouldn't happen if Home routed here, but
            // bail out gracefully.
            ContentUnavailableView(
                "No active workout",
                systemImage: "figure.run",
                description: Text("Pick a workout from the home screen.")
            )
        }
    }
}

// MARK: - Set page (the hero) — used by WatchModeRouter for the
// straight_sets / .none active block. Not private so the router can pick
// it up from the same module.

struct WatchSetCard: View {
    @Environment(WatchAppEnvironment.self) private var env
    let session: WorkoutSession

    @State private var actualReps: Int = 0
    @State private var actualWeightKg: Double = 0
    @State private var focused: Field = .reps
    @State private var lastSyncedSetId: SetId?

    enum Field { case reps, weight }

    var body: some View {
        let _ = session.tickCounter

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // 1. Top context bar
            topContextBar

            // 2. Big exercise name
            Text(currentExercise?.movementDisplayName ?? "—")
                .font(.fbb.watchTitle)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Set N of M + prescription line
            VStack(alignment: .leading, spacing: 1) {
                Text("Set \(setNumber) of \(totalSetsInExercise)")
                    .font(.fbb.label)
                    .foregroundStyle(Color.fbbOrange)
                Text(prescriptionText(for: currentSet))
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 4. Input cells
            HStack(spacing: Spacing.xxs) {
                WatchInputCell(
                    label: "REPS",
                    value: "\(actualReps)",
                    isFocused: focused == .reps
                ) {
                    focused = .reps
                    haptic(.click)
                }
                WatchInputCell(
                    label: session.weightUnit == .kg ? "KG" : "LB",
                    value: weightDisplay,
                    isFocused: focused == .weight
                ) {
                    focused = .weight
                    haptic(.click)
                }
            }
            .frame(height: 60)

            // 5. Done
            Button {
                haptic(.success)
                let entry = SetEntry(
                    outcome: .completed,
                    actualReps: actualReps == 0 ? nil : actualReps,
                    actualWeightKg: actualWeightKg == 0 ? nil : actualWeightKg,
                    actualRpe: nil
                )
                session.completeSet(entry)
            } label: {
                Label("Done set", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.fbbPrimary)

            // 6. Next-up hint
            if let nextName = nextExerciseName {
                Label("Next: \(nextName)", systemImage: "arrow.right")
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
        .focusable()
        .digitalCrownRotation(
            crownBinding,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: crownStep,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { resyncFromCurrentSet() }
        .onChange(of: session.cursor.setId) { _, _ in resyncFromCurrentSet() }
    }

    // MARK: - Top context bar

    private var topContextBar: some View {
        HStack(spacing: Spacing.xxs) {
            if let section = currentSection {
                Text(section.letter)
                    .font(.fbb.label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.fbbOrange, in: Capsule())
            }
            if let pos = exercisePositionInSection {
                Text("Ex \(pos)/\(totalExercisesInSection)")
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .semibold))
                Text(SessionMath.formatElapsed(session.totalElapsedSeconds()))
                    .font(.fbb.label)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: - Engine derivations

    private var currentSection: ParsedSection? {
        CursorAdvance.currentSection(session.cursor, in: session.day)
    }

    private var currentGroup: ParsedGroup? {
        CursorAdvance.currentGroup(session.cursor, in: session.day)
    }

    private var currentExercise: ParsedExercise? {
        CursorAdvance.currentExercise(session.cursor, in: session.day)
    }

    private var currentSet: ParsedSet? {
        CursorAdvance.currentSet(session.cursor, in: session.day)
    }

    /// 1-based ordinal of the current set within the current exercise.
    private var setNumber: Int {
        guard let ex = currentExercise else { return 0 }
        return (ex.sets.firstIndex(where: { $0.position == session.cursor.setPosition }) ?? 0) + 1
    }

    private var totalSetsInExercise: Int {
        currentExercise?.sets.count ?? 0
    }

    private var exercisePositionInSection: Int? {
        guard let section = currentSection,
              let ex = currentExercise,
              let group = currentGroup else { return nil }
        var pos = 0
        for g in section.groups {
            for e in g.exercises {
                guard !e.sets.isEmpty else { continue }
                pos += 1
                if e.position == ex.position && g.position == group.position {
                    return pos
                }
            }
        }
        return nil
    }

    private var totalExercisesInSection: Int {
        currentSection?.groups.reduce(0) { acc, g in
            acc + g.exercises.filter { !$0.sets.isEmpty }.count
        } ?? 0
    }

    private var nextExerciseName: String? {
        guard let next = CursorAdvance.next(after: session.cursor, in: session.day),
              let nextEx = CursorAdvance.currentExercise(next, in: session.day),
              nextEx.movementDisplayName != currentExercise?.movementDisplayName
        else { return nil }
        return nextEx.movementDisplayName
    }

    // MARK: - Helpers

    private var weightDisplay: String {
        if actualWeightKg == 0 { return "—" }
        let value = session.weightUnit == .kg
            ? actualWeightKg
            : actualWeightKg * 2.20462
        return value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private var crownBinding: Binding<Double> {
        switch focused {
        case .reps:
            return Binding(
                get: { Double(actualReps) },
                set: { actualReps = max(0, Int($0)) }
            )
        case .weight:
            return Binding(
                get: { actualWeightKg },
                set: { actualWeightKg = max(0, $0) }
            )
        }
    }

    private var crownRange: ClosedRange<Double> {
        switch focused {
        case .reps:   return 0...100
        case .weight: return 0...500
        }
    }

    private var crownStep: Double {
        switch focused {
        case .reps:   return 1
        case .weight: return session.weightUnit == .kg ? 2.5 : 5
        }
    }

    private func resyncFromCurrentSet() {
        let s = currentSet
        actualReps = s?.repsMin ?? s?.repsMax ?? 0
        actualWeightKg = 0
        focused = .reps
        lastSyncedSetId = session.cursor.setId
    }

    private func prescriptionText(for set: ParsedSet?) -> String {
        guard let set else { return "—" }
        var parts: [String] = []
        switch (set.repsMin, set.repsMax) {
        case (let lo?, let hi?) where lo == hi: parts.append("\(lo) reps")
        case (let lo?, let hi?):                parts.append("\(lo)–\(hi) reps")
        case (let lo?, nil):                    parts.append("\(lo) reps")
        case (nil, let hi?):                    parts.append("\(hi) reps")
        case (nil, nil):
            if let txt = set.repsText { parts.append(txt) }
        }
        if let tempo = set.tempo, !tempo.isEmpty { parts.append("@ \(tempo)") }
        if let rpeMin = set.rpeMin {
            if let rpeMax = set.rpeMax, rpeMax != rpeMin {
                parts.append("RPE \(formatRpe(rpeMin))–\(formatRpe(rpeMax))")
            } else {
                parts.append("RPE \(formatRpe(rpeMin))")
            }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func formatRpe(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}

// MARK: - Input cell

private struct WatchInputCell: View {
    let label: String
    let value: String
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                Text(label)
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 4)
                    .padding(.leading, 6)
                Text(value)
                    .font(.fbb.watchMetric)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isFocused ? Color.fbbOrange : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rest ring

private struct WatchRestRing: View {
    let session: WorkoutSession

    var body: some View {
        let _ = session.tickCounter
        let now = Date()
        let rest = session.restAfter
        let remaining = rest?.remainingSeconds(now: now) ?? 0
        let total = max(rest?.plannedSeconds ?? 60, 1)
        let progress = max(0.0, min(1.0, Double(remaining) / Double(total)))
        let isOvertime = (rest?.isOvertime(now: now)) ?? false

        VStack(spacing: Spacing.xxs) {
            HStack(spacing: 4) {
                Text("REST")
                    .font(.fbb.label)
                    .foregroundStyle(Color.inkMuted)
                if let nextEx = CursorAdvance.currentExercise(session.cursor, in: session.day) {
                    Text("· next: \(nextEx.movementDisplayName)")
                        .font(.fbb.label)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            ZStack {
                Circle()
                    .stroke(Color.inkMuted.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isOvertime ? Color.fbbStop : Color.fbbTeal,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(SessionMath.formatCountdown(remaining))
                    .font(.fbb.watchMetricHero)
                    .foregroundStyle(isOvertime ? Color.fbbStop : Color.inkPrimary)
                    .monospacedDigit()
            }
            .frame(width: 110, height: 110)
            .padding(.vertical, Spacing.xxs)

            HStack(spacing: Spacing.xxs) {
                Button("-15s") { session.extendRest(by: -15); haptic(.click) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.xs)
                    .background(Color.surfaceCard, in: Capsule())
                Button("Skip") { session.dismissRest(); haptic(.success) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.sm)
                    .background(Color.fbbTeal, in: Capsule())
                Button("+15s") { session.extendRest(by: 15); haptic(.click) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.xs)
                    .background(Color.surfaceCard, in: Capsule())
            }
            .font(.fbb.caption.bold())
        }
        .padding(.horizontal, Spacing.xs)
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}

// MARK: - Controls page

private struct WatchControlsView: View {
    let session: WorkoutSession
    let onEnd: () -> Void
    let onAbandon: (String) -> Void
    @State private var confirmingAbandon = false

    var body: some View {
        let _ = session.tickCounter
        VStack(spacing: Spacing.xs) {
            Text("ELAPSED")
                .font(.fbb.label)
                .foregroundStyle(Color.inkMuted)
            Text(SessionMath.formatElapsed(session.totalElapsedSeconds()))
                .font(.fbb.metricLarge)
                .foregroundStyle(Color.inkPrimary)

            Button {
                if session.isPaused {
                    session.resumeWorkout()
                    haptic(.start)
                } else {
                    session.pauseWorkout()
                    haptic(.click)
                }
            } label: {
                Label(
                    session.isPaused ? "Resume" : "Pause",
                    systemImage: session.isPaused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(.fbbPrimary)

            Button {
                haptic(.success)
                onEnd()
            } label: {
                Label("Finish", systemImage: "flag.checkered")
            }
            .buttonStyle(.fbbSecondary)

            Button {
                confirmingAbandon = true
            } label: {
                Text("Abandon")
                    .font(.fbb.caption.bold())
                    .foregroundStyle(Color.fbbStop)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xs)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $confirmingAbandon,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                haptic(.failure)
                onAbandon("user-discard")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}
