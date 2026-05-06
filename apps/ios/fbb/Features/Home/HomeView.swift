import SwiftUI

struct HomeView: View {
    @Bindable var vm: HomeViewModel
    @Environment(UserStore.self) private var userStore
    @State private var showQuizSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                header
                    .padding(.horizontal, Spacing.md)

                if userStore.selectedTrackCodes.isEmpty {
                    FindYourMatchCard(onStartQuiz: { showQuizSheet = true })
                        .padding(.horizontal, Spacing.md)

                    TodayNutritionCard(
                        selectedDate: vm.selectedDate ?? vm.todayISO,
                        dayKindHint: nil
                    )
                    .padding(.horizontal, Spacing.md)
                } else {
                    weekPicker
                        .padding(.horizontal, Spacing.md)

                    if vm.showBridgeBadge {
                        BridgeWeekBadge()
                            .padding(.horizontal, Spacing.md)
                    }

                    trackCardsSection
                        .padding(.horizontal, Spacing.md)

                    MoreTracksCard(onStartQuiz: { showQuizSheet = true })
                        .padding(.horizontal, Spacing.md)

                    TodayNutritionCard(
                        selectedDate: vm.selectedDate,
                        dayKindHint: vm.workoutDayKindHint
                    )
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .background(Color.fbbBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await vm.refresh() }
        .task { await vm.onAppear() }
        .sheet(isPresented: $showQuizSheet) {
            TrackQuizSheet(
                userStore: userStore,
                onDone: { showQuizSheet = false }
            )
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(vm.headerTitle)
                .font(.fbb.display)
                .foregroundStyle(Color.inkPrimary)
            if let microcycleLabel = vm.microcycleLabel {
                Text(microcycleLabel)
                    .font(.fbb.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekPicker: some View {
        WeekDayPicker(
            items: vm.weekItems,
            selectedDate: vm.selectedDate,
            todayISO: vm.todayISO,
            weekRangeLabel: vm.weekRangeLabel,
            microcycleLabel: vm.microcycleLabel,
            canGoPrevious: vm.canGoPreviousWeek,
            canGoNext: vm.canGoNextWeek,
            onSelect: { vm.selectDate($0) },
            onPrevious: { vm.goToPreviousWeek() },
            onNext: { vm.goToNextWeek() }
        )
    }

    @ViewBuilder
    private var trackCardsSection: some View {
        switch vm.dayDetail {
        case .idle, .loading:
            VStack(spacing: Spacing.sm) {
                trackCardSkeleton
                trackCardSkeleton
            }

        case .loaded:
            if vm.followedDayCells.isEmpty {
                EmptyDayInWeekCard()
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(vm.followedDayCells) { cell in
                        if let week = vm.viewedWeek.value, let date = vm.selectedDate {
                            NavigationLink(value: NavRoute.day(week: week.weekStartsOn, day: date)) {
                                TrackWorkoutCard(cell: cell, onTap: {})
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .failed(let err):
            ErrorCard(
                title: "Couldn't load this day",
                message: err.errorDescription,
                isRetryable: err.isRetryable,
                retry: { Task { await vm.refresh() } }
            )
        }
    }

    private var trackCardSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SkeletonBlock(width: 30, height: 30, corner: 8)
                SkeletonBlock(width: 140, height: 14)
                Spacer()
                SkeletonBlock(width: 70, height: 18, corner: 9)
            }
            SkeletonBlock(width: 220, height: 22)
            SkeletonBlock(height: 12)
            SkeletonBlock(height: 12)
        }
        .padding(Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
    }
}

// MARK: - Empty day in week card

private struct EmptyDayInWeekCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No workout scheduled")
                .font(.fbb.bodyBold)
                .foregroundStyle(Color.inkPrimary)
            Text("Pick another day from the picker above.")
                .font(.fbb.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }
}

