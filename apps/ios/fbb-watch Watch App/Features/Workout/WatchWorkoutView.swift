import SwiftUI
import WatchKit
import FBBDesignSystem
import FBBWorkoutKitCore

/// Active session screen. Paged TabView with three pages — Set / Rest /
/// Controls. Rest page is auto-presented when the store reports `isResting`
/// and auto-pops back to Set when the timer expires.
struct WatchWorkoutView: View {
    @Environment(WatchAppEnvironment.self) private var env
    @Binding var path: NavigationPath
    @State private var pageIndex = 0

    var body: some View {
        // Force re-render every tick so timers update.
        let _ = env.session.tickCounter

        TabView(selection: $pageIndex) {
            WatchSetCard()
                .tag(0)

            WatchRestRing()
                .tag(1)

            WatchControlsView(
                onEnd: {
                    env.session.end()
                    path.append(WatchRoute.summary)
                },
                onAbandon: {
                    env.session.abandon()
                    path.append(WatchRoute.summary)
                }
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden(true)
        .onChange(of: env.session.isResting) { _, isResting in
            // Auto-present the rest page when a rest starts; auto-pop back
            // to Set when it expires.
            withAnimation { pageIndex = isResting ? 1 : 0 }
        }
    }
}

// MARK: - Set page (the hero)

private struct WatchSetCard: View {
    @Environment(WatchAppEnvironment.self) private var env

    @State private var actualReps: Int = 0
    @State private var actualWeightKg: Double = 0
    @State private var focused: Field = .reps

    enum Field { case reps, weight }

    var body: some View {
        let session = env.session
        let exercise = session.currentExercise
        let set = session.currentSet

        VStack(spacing: Spacing.xs) {
            // Header
            HStack(spacing: Spacing.xxs) {
                Text(exercise?.movementDisplayName ?? "—")
                    .font(.fbb.watchTitle)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Text("\(session.setIdx + 1)/\(session.totalSetsInCurrentExercise)")
                    .font(.fbb.label)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.surfaceCard, in: Capsule())
                    .foregroundStyle(Color.inkSecondary)
            }

            // Prescription
            Text(prescriptionText(for: set))
                .font(.fbb.caption)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Input cells
            HStack(spacing: Spacing.xs) {
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
            .frame(maxHeight: .infinity)

            // Done
            Button {
                haptic(.success)
                env.session.logCurrentSet(
                    actualReps: actualReps == 0 ? nil : actualReps,
                    actualWeightKg: actualWeightKg == 0 ? nil : actualWeightKg,
                    actualRpe: nil
                )
                resyncFromCurrentSet()
            } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.fbbPrimary)
        }
        .padding(.horizontal, Spacing.xs)
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
        .onChange(of: env.session.setIdx) { _, _ in resyncFromCurrentSet() }
        .onChange(of: env.session.exerciseIdx) { _, _ in resyncFromCurrentSet() }
    }

    private var weightDisplay: String {
        if actualWeightKg == 0 { return "—" }
        let value = env.session.weightUnit == .kg
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
        case .weight: return env.session.weightUnit == .kg ? 2.5 : 5
        }
    }

    private func resyncFromCurrentSet() {
        // Pre-fill from prescription when we land on a new set, so the no-touch
        // case is `tap Done` => log prescribed.
        let s = env.session.currentSet
        actualReps = s?.repsMin ?? s?.repsMax ?? 0
        actualWeightKg = 0
        focused = .reps
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
        return parts.joined(separator: " · ")
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
                    .font(.fbb.watchMetricHero)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, minHeight: 70, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
                    .fill(Color.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous)
                            .strokeBorder(isFocused ? Color.fbbOrange : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rest ring

private struct WatchRestRing: View {
    @Environment(WatchAppEnvironment.self) private var env

    var body: some View {
        let _ = env.session.tickCounter
        let remaining = env.session.restRemainingSeconds ?? 0
        let total = max(env.session.currentSet?.restAfterSecondsMin ?? 60, 1)
        let progress = min(1.0, Double(remaining) / Double(total))

        VStack(spacing: Spacing.xxs) {
            Text("REST")
                .font(.fbb.label)
                .foregroundStyle(Color.inkMuted)
            ZStack {
                Circle()
                    .stroke(Color.inkMuted.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        env.session.isResting ? Color.fbbTeal : Color.fbbStop,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(formatTime(remaining))
                    .font(.fbb.watchMetricHero)
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
            }
            .frame(width: 110, height: 110)
            .padding(.vertical, Spacing.xxs)

            HStack(spacing: Spacing.xxs) {
                Button("-15s") { env.session.adjustRest(by: -15); haptic(.click) }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.xs)
                    .background(Color.surfaceCard, in: Capsule())
                Button("Skip") { env.session.skipRest(); haptic(.success) }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.sm)
                    .background(Color.fbbTeal, in: Capsule())
                    .foregroundStyle(.white)
                Button("+15s") { env.session.adjustRest(by: 15); haptic(.click) }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, Spacing.xs)
                    .background(Color.surfaceCard, in: Capsule())
            }
            .font(.fbb.caption)
        }
        .padding(.horizontal, Spacing.xs)
        .focusable()
        .digitalCrownRotation(
            Binding(
                get: { Double(env.session.restRemainingSeconds ?? 0) },
                set: { newValue in
                    let delta = Int(newValue) - (env.session.restRemainingSeconds ?? 0)
                    if delta != 0 { env.session.adjustRest(by: delta) }
                }
            ),
            from: 0,
            through: 600,
            by: 5,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}

// MARK: - Controls page

private struct WatchControlsView: View {
    @Environment(WatchAppEnvironment.self) private var env
    let onEnd: () -> Void
    let onAbandon: () -> Void
    @State private var confirmingAbandon = false

    var body: some View {
        let _ = env.session.tickCounter
        VStack(spacing: Spacing.xs) {
            Text("ELAPSED")
                .font(.fbb.label)
                .foregroundStyle(Color.inkMuted)
            Text(formatElapsed(env.session.elapsedSeconds))
                .font(.fbb.metricLarge)
                .foregroundStyle(Color.inkPrimary)

            Button {
                haptic(.success)
                onEnd()
            } label: {
                Label("Finish", systemImage: "flag.checkered")
            }
            .buttonStyle(.fbbPrimary)

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
                onAbandon()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}
