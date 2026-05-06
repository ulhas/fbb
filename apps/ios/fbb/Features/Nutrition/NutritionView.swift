import SwiftUI

struct NutritionView: View {
    @State private var vm = NutritionViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showVisibilitySheet = false
    @State private var quickAddInfoMessage: String?
    @State private var showQuickAddInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WeekDayPicker(
                    items: vm.weekItems,
                    selectedDate: vm.selectedDate,
                    todayISO: vm.todayISO,
                    weekRangeLabel: vm.weekRangeLabel,
                    microcycleLabel: nil,
                    canGoPrevious: vm.canGoPreviousWeek,
                    canGoNext: vm.canGoNextWeek,
                    onSelect: { vm.selectDate($0) },
                    onPrevious: { vm.goToPreviousWeek() },
                    onNext: { vm.goToNextWeek() }
                )
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xs)

                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    switch vm.day {
                    case .idle, .loading:
                        NutritionSkeleton()
                            .transition(.opacity)
                    case .failed(let error):
                        ErrorCard(
                            title: "Couldn't load nutrition",
                            message: error.isRetryable ? "Pull to retry, or tap below." : nil,
                            isRetryable: error.isRetryable,
                            retry: { Task { await vm.refresh() } }
                        )
                    case .loaded(let day):
                        NutritionContent(
                            day: day,
                            onQuickAddAction: handle(_:),
                            onAddToMeal: { _ in
                                quickAddInfoMessage = "Manual logging is coming soon."
                                showQuickAddInfo = true
                            }
                        )
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
                .animation(reduceMotion ? nil : Motion.standard, value: caseTag(vm.day))
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.fbbBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoachVisibilityChip(
                    coachName: vm.day.value?.coachName,
                    onTap: { showVisibilitySheet = true }
                )
            }
        }
        .refreshable { await vm.refresh() }
        .task { await vm.onAppear() }
        .sheet(isPresented: $showVisibilitySheet) {
            CoachVisibilitySheet(coachName: vm.day.value?.coachName)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Coming soon", isPresented: $showQuickAddInfo, presenting: quickAddInfoMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func handle(_ action: QuickAddRow.QuickAddAction) {
        switch action {
        case .photo:
            quickAddInfoMessage = "Photo logging arrives in Phase 4 — point at your plate, AI extracts macros."
        case .barcode:
            quickAddInfoMessage = "Barcode scanner is wired up to the foods table on the backend; UI ships next."
        case .search:
            quickAddInfoMessage = "Food search opens here. Backend supports USDA, Open Food Facts, and Nutritionix."
        case .logFood(let s):
            quickAddInfoMessage = "Tapped \(s.label). Manual logging UI is coming soon."
        case .logMeal(let s):
            quickAddInfoMessage = "Tapped saved meal: \(s.label). Manual logging UI is coming soon."
        }
        showQuickAddInfo = true
    }

    private func caseTag<V>(_ s: NutritionViewModel.LoadState<V>) -> Int {
        switch s {
        case .idle:    return 0
        case .loading: return 1
        case .loaded:  return 2
        case .failed:  return 3
        }
    }
}

// MARK: - Loaded content

private struct NutritionContent: View {
    let day: NutritionDay
    let onQuickAddAction: (QuickAddRow.QuickAddAction) -> Void
    let onAddToMeal: (MealKind) -> Void

    var body: some View {
        Group {
            MacroHeroCard(
                target: day.target,
                logged: day.logged,
                coachLine: day.coachLine
            )

            QuickAddRow(
                recents: day.recents,
                savedMeals: day.savedMeals,
                onAction: onQuickAddAction
            )

            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(day.meals) { meal in
                    MealSection(meal: meal, onAdd: { onAddToMeal(meal.kind) })
                }
            }

            WeeklyCaloriesCard(days: day.weekly)
            MacroConsistencyCard(consistency: day.consistency)
            BodyWeightTrendCard(weight: day.weight)
            NutritionInsightsList(insights: day.insights, onAction: { _, _ in })

            if let coachName = day.coachName {
                CoachFooter(coachName: coachName)
                    .padding(.top, Spacing.lg)
            }
        }
    }
}

// MARK: - Coach footer

private struct CoachFooter: View {
    let coachName: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.fbbTeal)
                Text("Visible to Coach \(coachName)")
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
            Button {
                // Mock — pause sharing UI is Phase 2
            } label: {
                Text("Pause sharing")
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.fbbTeal)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Visibility sheet

private struct CoachVisibilitySheet: View {
    let coachName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.fbbTeal)
                    Text("Coach view")
                        .font(.fbb.title2)
                        .foregroundStyle(Color.inkPrimary)
                }

                Text("Your nutrition logs, training adherence, and recovery signals are visible to:")
                    .font(.fbb.body)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Bullet(symbol: "person.fill", title: "Coach \(coachName ?? "(none assigned)")", message: "Reads weekly summaries to write your next block.")
                    Bullet(symbol: "sparkles",    title: "AI Coach",                                message: "Generates insights and answers your questions in real time.")
                }

                Divider().background(Color.fbbDivider)

                Text("You can pause sharing for any block at any time. Your data is never sold.")
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)

                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
        }
        .background(Color.fbbBackground.ignoresSafeArea())
    }
}

private struct Bullet: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.fbbTeal)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fbb.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                Text(message)
                    .font(.fbb.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Loading skeleton

private struct NutritionSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(alignment: .center, spacing: Spacing.md) {
                Circle()
                    .fill(Color.inkMuted.opacity(0.18))
                    .frame(width: 180, height: 180)
                HStack(spacing: Spacing.lg) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.inkMuted.opacity(0.18))
                            .frame(width: 60, height: 60)
                    }
                }
                SkeletonBlock(height: 32)
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner))
            .elevation(.card)

            HStack {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(width: 110, height: 36)
                }
            }

            VStack(spacing: Spacing.sm) {
                SkeletonBlock(height: 80)
                SkeletonBlock(height: 80)
                SkeletonBlock(height: 80)
                SkeletonBlock(height: 80)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        NutritionView()
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
    }
}
