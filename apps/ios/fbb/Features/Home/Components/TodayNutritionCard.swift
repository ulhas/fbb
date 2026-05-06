import SwiftUI

/// Compact "today's fueling" surface that lives between the workout hero
/// and the week strip. Reads from the same mock source the Nutrition tab
/// uses so the two stay in sync; reflects the date that Home's day strip
/// currently focuses (rest-day variant tones down macro nagging).
///
/// On tap of "Quick add" we surface the existing `QuickAddRow` in a sheet
/// instead of duplicating the picker; "Open log" is a placeholder for the
/// programmatic tab switch (deep-link to Nutrition with the same date)
/// which lands when we add a `TabRouter`.
struct TodayNutritionCard: View {
    let selectedDate: String?
    let dayKindHint: DayKind?

    @State private var day: LoadState = .idle
    @State private var showQuickAdd = false
    @State private var showOpenLogPlaceholder = false
    private let source: any NutritionSource = MockNutritionSource()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(NutritionDay)
        case failed(String)

        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading): return true
            case (.loaded(let a), .loaded(let b)): return a.date == b.date
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header

            switch day {
            case .idle, .loading:
                skeleton
            case .failed(let message):
                Text(message)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.semanticWarning)
            case .loaded(let value):
                content(for: value)
                actions(for: value)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .task(id: selectedDate ?? "") {
            await load()
        }
        .sheet(isPresented: $showQuickAdd) {
            if case .loaded(let value) = day {
                QuickAddSheet(day: value, onClose: { showQuickAdd = false })
            }
        }
        .alert("Coming soon", isPresented: $showOpenLogPlaceholder) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Programmatic jump to the Nutrition tab with this date arrives in the next pass.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerEyebrow.uppercased())
                    .font(.fbb.label).tracking(1.2)
                    .foregroundStyle(Color.fbbTeal)
                Text(headerTitle)
                    .font(.fbb.title3)
                    .foregroundStyle(Color.inkPrimary)
            }
            Spacer()
            if let dateLabel {
                Text(dateLabel)
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func content(for value: NutritionDay) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                MacroRing(
                    progress: caloriesProgress(value),
                    lineWidth: 9,
                    tint: caloriesTint(value)
                )
                .frame(width: 86, height: 86)

                VStack(spacing: 0) {
                    Text("\(value.logged.kcal)")
                        .font(.fbb.metric)
                        .foregroundStyle(Color.inkPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kcal")
                        .font(.fbb.label).tracking(0.8)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(remainingHeadline(value))
                    .font(.fbb.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                MacroLine(
                    label: "Protein", logged: value.logged.proteinG,
                    target: value.target.proteinG, tint: .fbbOrange, isPriority: true
                )
                MacroLine(
                    label: "Carbs", logged: value.logged.carbsG,
                    target: value.target.carbsG, tint: .fbbTeal
                )
                MacroLine(
                    label: "Fat", logged: value.logged.fatG,
                    target: value.target.fatG, tint: .inkSecondary
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actions(for value: NutritionDay) -> some View {
        HStack(spacing: Spacing.xs) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showQuickAdd = true
            } label: {
                Label("Quick add", systemImage: "plus.circle.fill")
                    .font(.fbb.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.fbbOrange, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                showOpenLogPlaceholder = true
            } label: {
                Label("Open log", systemImage: "arrow.up.right.square")
                    .font(.fbb.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.fbbOrange)
            .background(
                Color.fbbOrangeTint.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
    }

    private var skeleton: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Circle()
                .fill(Color.inkMuted.opacity(0.18))
                .frame(width: 86, height: 86)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 220, height: 16)
                SkeletonBlock(height: 12)
                SkeletonBlock(height: 12)
                SkeletonBlock(height: 12)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let date = selectedDate else {
            day = .idle
            return
        }
        day = .loading
        do {
            let value = try await source.loadDay(date: date, forceRefresh: false)
            day = .loaded(value)
        } catch {
            day = .failed("Couldn't load nutrition for this day.")
        }
    }

    // MARK: - Copy

    private var headerEyebrow: String {
        switch dayKindHint {
        case .rest:            return "Rest day fuel"
        case .activeRecovery:  return "Recovery fuel"
        case .mobility:        return "Light day fuel"
        case .lesson:          return "Today's fuel"
        case .workout, .none:  return "Today's fuel"
        }
    }

    private var headerTitle: String {
        switch dayKindHint {
        case .rest:           return "Same protein, lighter carbs"
        case .activeRecovery: return "Steady macros, hydrate"
        default:              return "Macros"
        }
    }

    private var dateLabel: String? {
        guard let selectedDate else { return nil }
        return ISODate.monthDay(selectedDate)
    }

    // MARK: - Calorie math

    private func caloriesProgress(_ value: NutritionDay) -> Double {
        Double(value.logged.kcal) / max(Double(value.target.kcal), 1)
    }

    private func caloriesTint(_ value: NutritionDay) -> Color {
        if value.logged.kcal > value.target.kcal { return .semanticWarning }
        if Double(value.logged.kcal) > Double(value.target.kcal) * 0.95 { return .semanticSuccess }
        return .fbbOrange
    }

    private func remainingHeadline(_ value: NutritionDay) -> String {
        let diff = value.target.kcal - value.logged.kcal
        if diff < 0 {
            return "Over by \(formatted(-diff)) kcal"
        }
        if diff == 0 {
            return "On target"
        }
        return "\(formatted(diff)) kcal to go"
    }

    private func formatted(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - Macro line

private struct MacroLine: View {
    let label: String
    let logged: Int
    let target: Int
    let tint: Color
    var isPriority: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.fbb.caption.weight(isPriority ? .bold : .regular))
                .foregroundStyle(Color.inkPrimary)
            Spacer(minLength: Spacing.xs)
            Text("\(logged)/\(target) g")
                .font(.fbb.caption.weight(.semibold))
                .foregroundStyle(remainingTint)
                .monospacedDigit()
        }
    }

    private var remainingTint: Color {
        if logged >= target { return .semanticSuccess }
        return .inkSecondary
    }
}

// MARK: - Quick add sheet

private struct QuickAddSheet: View {
    let day: NutritionDay
    let onClose: () -> Void

    @State private var infoMessage: String?
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Drop in something you already eat. Manual logging UI lands in the next pass.")
                        .font(.fbb.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, Spacing.md)

                    QuickAddRow(
                        recents: day.recents,
                        savedMeals: day.savedMeals,
                        onAction: handle
                    )
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.fbbBackground.ignoresSafeArea())
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .font(.fbb.bodyBold)
                        .foregroundStyle(Color.fbbOrange)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Coming soon", isPresented: $showInfo, presenting: infoMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func handle(_ action: QuickAddRow.QuickAddAction) {
        switch action {
        case .photo:           infoMessage = "Photo logging arrives in Phase 4 — point at your plate, AI extracts macros."
        case .barcode:         infoMessage = "Barcode scanner is wired up to the foods table on the backend; UI ships next."
        case .search:          infoMessage = "Food search opens here. Backend supports USDA, Open Food Facts, and Nutritionix."
        case .logFood(let s):  infoMessage = "Tapped \(s.label). Manual logging UI is coming soon."
        case .logMeal(let s):  infoMessage = "Tapped saved meal: \(s.label). Manual logging UI is coming soon."
        }
        showInfo = true
    }
}
