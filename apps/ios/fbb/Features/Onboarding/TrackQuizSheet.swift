import SwiftUI

/// Modal track-discovery flow. Replaces the multi-select placeholder with
/// the four-question quiz from FBB live (Equipment → Goal → Preference →
/// Cadence) ending on a "Choose your track" recommendation. Selection is
/// staged locally; commits happen on the result screen so the sheet
/// doesn't dismiss itself mid-flow.
///
/// Aesthetic targets:
///   - One confident focal point per screen — eyebrow up top, big bold
///     question, soft option cards, sticky CTA at the bottom.
///   - Subtle warm gradient at the top of every screen so the modal
///     feels lit, not just monochrome.
///   - Spring transitions between steps; selection scale + haptics.
///   - Result screen earns a moment: primary card has a family-tinted
///     hero, alternates collapse into a compact pair below.
struct TrackQuizSheet: View {
    let userStore: UserStore
    let onDone: () -> Void

    @State private var step: QuizStep = .equipment
    @State private var answers = QuizAnswers()
    @State private var isCommitting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                background

                VStack(spacing: 0) {
                    if step != .result {
                        ProgressDots(current: step)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, Spacing.md)
                    }

                    Group {
                        switch step {
                        case .equipment:
                            QuizQuestionView(
                                ordinal: step.ordinalLabel,
                                title: "What best describes your equipment?",
                                options: QuizEquipment.allCases,
                                selection: answers.equipment,
                                label: { $0.label },
                                onSelect: { answers.equipment = $0; advanceIfReady() }
                            )
                        case .goal:
                            QuizQuestionView(
                                ordinal: step.ordinalLabel,
                                title: "What's your primary goal?",
                                options: QuizGoal.allCases,
                                selection: answers.goal,
                                label: { $0.label },
                                onSelect: { answers.goal = $0; advanceIfReady() }
                            )
                        case .preference:
                            QuizQuestionView(
                                ordinal: step.ordinalLabel,
                                title: "Which do you prefer?",
                                options: QuizPreference.allCases,
                                selection: answers.preference,
                                label: { $0.label },
                                onSelect: { answers.preference = $0; advanceIfReady() }
                            )
                        case .cadence:
                            QuizQuestionView(
                                ordinal: step.ordinalLabel,
                                title: "How often can you train?",
                                options: QuizCadence.allCases,
                                selection: answers.cadence,
                                label: { $0.label },
                                onSelect: { answers.cadence = $0; advanceIfReady() }
                            )
                        case .result:
                            QuizResultView(
                                answers: answers,
                                userStore: userStore,
                                isCommitting: $isCommitting,
                                onCommitted: onDone,
                                onRetake: resetQuiz
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar { closeToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if step != .result { footer }
            }
            .task { await userStore.loadCatalog() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            Color.fbbBackground
            LinearGradient(
                colors: [
                    Color.fbbOrange.opacity(0.14),
                    Color.fbbOrange.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onDone) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.surfaceCard, in: Circle())
                    .overlay(
                        Circle().strokeBorder(Color.fbbDivider.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Close quiz")
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            if step.rawValue > QuizStep.equipment.rawValue {
                Button(action: stepBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.fbbOrange)
                        .labelStyle(BackLabelStyle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: stepForward) {
                HStack(spacing: 6) {
                    Text(step == .cadence ? "See match" : "Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(.fbb.bodyBold)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, Spacing.lg)
                .background(continueBackground, in: Capsule())
                .shadow(
                    color: answers.isComplete(through: step)
                        ? Color.fbbOrange.opacity(0.35) : .clear,
                    radius: 14, x: 0, y: 6
                )
            }
            .buttonStyle(PressedScaleButtonStyle())
            .disabled(!answers.isComplete(through: step))
            .opacity(answers.isComplete(through: step) ? 1 : 0.55)
            .animation(reduceMotion ? nil : .snappy, value: answers.isComplete(through: step))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var continueBackground: LinearGradient {
        LinearGradient(
            colors: [Color.fbbOrange, Color.fbbOrangeDark],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Navigation

    private func stepBack() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let prev = QuizStep(rawValue: step.rawValue - 1) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                step = prev
            }
        }
    }

    private func stepForward() {
        guard answers.isComplete(through: step), let next = step.next else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = next
        }
    }

    /// Auto-advance one step after a tap if the user has made a selection.
    /// Cuts the friction on the binary screens (Equipment, Preference) where
    /// "tap option then tap Continue" feels redundant. We still keep the
    /// Continue button for keyboard / accessibility / undecided users.
    private func advanceIfReady() {
        guard answers.isComplete(through: step), let next = step.next else { return }
        // Tiny delay so the user sees the selected state before the
        // transition kicks in — keeps the cause-and-effect readable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard answers.isComplete(through: step) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                step = next
            }
        }
    }

    private func resetQuiz() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            answers = QuizAnswers()
            step = .equipment
        }
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let current: QuizStep

    private let questionSteps: [QuizStep] = [.equipment, .goal, .preference, .cadence]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(questionSteps, id: \.self) { step in
                Capsule()
                    .fill(state(for: step) == .completed ? Color.fbbOrange
                          : state(for: step) == .current ? Color.fbbOrange.opacity(0.55)
                          : Color.inkMuted.opacity(0.35))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of 4")
    }

    private enum DotState { case completed, current, upcoming }

    private func state(for step: QuizStep) -> DotState {
        if step.rawValue < current.rawValue { return .completed }
        if step.rawValue == current.rawValue { return .current }
        return .upcoming
    }
}

// MARK: - Question screen

private struct QuizQuestionView<Option: Hashable>: View {
    let ordinal: String
    let title: String
    let options: [Option]
    let selection: Option?
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ordinal.uppercased())
                        .font(.fbb.label).tracking(1.4)
                        .foregroundStyle(Color.fbbOrange)
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.top, Spacing.lg)

                VStack(spacing: Spacing.xs) {
                    ForEach(options, id: \.self) { option in
                        OptionCard(
                            label: label(option),
                            isSelected: option == selection,
                            onTap: { onSelect(option) }
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }
}

private struct OptionCard: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            onTap()
        }) {
            HStack(spacing: Spacing.sm) {
                checkmark
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.inkPrimary : Color.inkPrimary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.md + 4)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(border)
            .shadow(
                color: isSelected ? Color.fbbOrange.opacity(0.18) : Color.black.opacity(0.04),
                radius: isSelected ? 14 : 6,
                x: 0,
                y: isSelected ? 6 : 2
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
        .scaleEffect(isSelected ? 1.015 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.fbbOrange : Color.clear)
                .frame(width: 22, height: 22)
            Circle()
                .strokeBorder(
                    isSelected ? Color.fbbOrange : Color.inkMuted.opacity(0.45),
                    lineWidth: 1.6
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            LinearGradient(
                colors: [
                    Color.fbbOrangeTint.opacity(0.55),
                    Color.surfaceCard,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.surfaceCard
        }
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                isSelected ? Color.fbbOrange : Color.inkMuted.opacity(0.18),
                lineWidth: isSelected ? 1.6 : 1
            )
    }
}

// MARK: - Back label style — chevron tight against the text

private struct BackLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Result screen

private struct QuizResultView: View {
    let answers: QuizAnswers
    let userStore: UserStore
    @Binding var isCommitting: Bool
    let onCommitted: () -> Void
    let onRetake: () -> Void

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                switch userStore.catalog {
                case .idle, .loading:
                    loadingState
                case .failed(let err):
                    ErrorCard(
                        title: "Couldn't load tracks",
                        message: err.errorDescription,
                        isRetryable: err.isRetryable,
                        retry: { Task { await userStore.loadCatalog(force: true) } }
                    )
                case .loaded(let rows):
                    let recs = QuizRecommender.recommend(from: answers, catalog: rows)
                    if recs.isEmpty {
                        Text("Hmm, we couldn't find a great match. Try the picker on your profile to follow any track manually.")
                            .font(.fbb.body)
                            .foregroundStyle(Color.inkSecondary)
                    } else {
                        recommendations(recs)

                        AnswersChipRow(answers: answers, onRetake: onRetake)
                            .padding(.top, Spacing.md)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 16)
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82), value: revealed)
        .onAppear { revealed = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.fbbOrange)
                Text("YOUR MATCH")
                    .font(.fbb.label).tracking(1.4)
                    .foregroundStyle(Color.fbbOrange)
            }
            Text("Curated for you")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            Text("Built from your answers. You can change tracks anytime from your profile.")
                .font(.fbb.body)
                .foregroundStyle(Color.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func recommendations(_ recs: [QuizRecommendation]) -> some View {
        if let primary = recs.first(where: { $0.kind == .primary }) {
            PrimaryRecommendationCard(
                recommendation: primary,
                isCommitting: isCommitting,
                onChoose: { commit(primary) }
            )
        }

        let alternates = recs.filter { $0.kind == .alternate }
        if !alternates.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("OR TRY")
                    .font(.fbb.label).tracking(1.2)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, Spacing.xs)

                VStack(spacing: Spacing.xs) {
                    ForEach(alternates) { rec in
                        AlternateRecommendationRow(
                            recommendation: rec,
                            disabled: isCommitting,
                            onChoose: { commit(rec) }
                        )
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            SkeletonBlock(height: 220, corner: 16)
            SkeletonBlock(height: 80, corner: 12)
            SkeletonBlock(height: 80, corner: 12)
        }
    }

    private func commit(_ rec: QuizRecommendation) {
        guard !isCommitting else { return }
        isCommitting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        userStore.follow(rec.code)
        onCommitted()
    }
}

// MARK: - Primary recommendation card

private struct PrimaryRecommendationCard: View {
    let recommendation: QuizRecommendation
    let isCommitting: Bool
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(recommendation.track.displayName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                    if let cadence = recommendation.track.cadence {
                        Text(cadence.uppercased())
                            .font(.fbb.label).tracking(0.6)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.vertical, 3).padding(.horizontal, 8)
                            .background(Color.inkMuted.opacity(0.18), in: Capsule())
                    }
                }

                if let description = recommendation.track.description {
                    Text(description)
                        .font(.fbb.body)
                        .foregroundStyle(Color.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.fbbOrange)
                        .padding(.top, 2)
                    Text(recommendation.reason)
                        .font(.fbb.caption.weight(.semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .background(
                    Color.fbbOrangeTint.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                Button(action: onChoose) {
                    HStack(spacing: 8) {
                        if isCommitting {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Get started")
                    }
                    .font(.fbb.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        LinearGradient(
                            colors: [Color.fbbOrange, Color.fbbOrangeDark],
                            startPoint: .top, endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color.fbbOrange.opacity(0.35), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(PressedScaleButtonStyle())
                .disabled(isCommitting)
                .padding(.top, 4)
            }
            .padding(Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.fbbOrange.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [familyTint, familyTint.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative concentric rings — gives the hero some texture
            // without pulling in actual track imagery.
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<4) { i in
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1.2)
                            .frame(width: CGFloat(180 + i * 60), height: CGFloat(180 + i * 60))
                            .offset(x: geo.size.width * 0.45, y: -geo.size.height * 0.25)
                    }
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 6) {
                Text("RECOMMENDED")
                    .font(.fbb.label).tracking(1.4)
                    .foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 10)
                    .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))

                Image(systemName: familySymbol)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.top, Spacing.xs)
            }
            .padding(.vertical, Spacing.md)
        }
        .frame(height: 180)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
        )
    }

    private var familyTint: Color {
        switch recommendation.track.family {
        case "pump_lift", "perform":                            return .fbbOrange
        case "pump_condition", "minimalist", "hybrid_running":  return .fbbTeal
        default:                                                return .inkMuted
        }
    }

    private var familySymbol: String {
        switch recommendation.track.family {
        case "pump_lift":      return "dumbbell.fill"
        case "pump_condition": return "wind"
        case "perform":        return "flame.fill"
        case "minimalist":     return "circle.dashed"
        case "hybrid_running": return "figure.run"
        case "workshop":       return "wrench.and.screwdriver.fill"
        case "onramp":         return "arrow.up.right"
        default:               return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Alternate row

private struct AlternateRecommendationRow: View {
    let recommendation: QuizRecommendation
    let disabled: Bool
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: familySymbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(familyTint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(recommendation.track.displayName)
                            .font(.fbb.bodyBold)
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        if let cadence = recommendation.track.cadence {
                            Text(cadence.uppercased())
                                .font(.fbb.label).tracking(0.6)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    Text(recommendation.reason)
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.fbbOrange)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.inkMuted.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
        .disabled(disabled)
    }

    private var familyTint: Color {
        switch recommendation.track.family {
        case "pump_lift", "perform":                            return .fbbOrange
        case "pump_condition", "minimalist", "hybrid_running":  return .fbbTeal
        default:                                                return .inkMuted
        }
    }

    private var familySymbol: String {
        switch recommendation.track.family {
        case "pump_lift":      return "dumbbell.fill"
        case "pump_condition": return "wind"
        case "perform":        return "flame.fill"
        case "minimalist":     return "circle.dashed"
        case "hybrid_running": return "figure.run"
        case "workshop":       return "wrench.and.screwdriver.fill"
        case "onramp":         return "arrow.up.right"
        default:               return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Answers recap (with retake)

private struct AnswersChipRow: View {
    let answers: QuizAnswers
    let onRetake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("HOW WE PICKED")
                .font(.fbb.label).tracking(1.2)
                .foregroundStyle(Color.inkSecondary)

            FlowLayout(spacing: 6) {
                if let goal = answers.goal {
                    chip(label: goal.label)
                }
                if let preference = answers.preference {
                    chip(label: preference.label)
                }
                if let equipment = answers.equipment {
                    chip(label: equipment == .limited ? "Limited gear" : "Varied gear")
                }
                if let cadence = answers.cadence {
                    chip(label: cadence.label)
                }
            }

            Button(action: onRetake) {
                Label("Retake quiz", systemImage: "arrow.counterclockwise")
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.fbbOrange)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.inkMuted.opacity(0.18), lineWidth: 1)
        )
    }

    private func chip(label: String) -> some View {
        Text(label)
            .font(.fbb.caption.weight(.semibold))
            .foregroundStyle(Color.inkPrimary)
            .padding(.vertical, 5).padding(.horizontal, 10)
            .background(Color.fbbOrangeTint.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.fbbOrange.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Tiny flow layout for the chip recap row

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let arranged = arrange(subviews: subviews, in: maxWidth)
        let height = arranged.last.map { $0.origin.y + $0.size.height } ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : arranged.map { $0.origin.x + $0.size.width }.max() ?? 0,
                      height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(subviews: subviews, in: bounds.width)
        for (i, frame) in arranged.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                              proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [CGRect] {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}
