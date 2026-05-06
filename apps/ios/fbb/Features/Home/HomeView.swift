import SwiftUI

struct HomeView: View {
    @Bindable var vm: HomeViewModel
    @Environment(EntitlementsStore.self) private var entitlements
    @State private var showLoggerPlaceholder = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                header

                if entitlements.selectedTrackCodes.isEmpty {
                    NoTracksSelectedView()
                        .padding(.horizontal, Spacing.md)
                } else {
                    if !vm.availableTracks.isEmpty {
                        TrackSelector(
                            tracks: vm.availableTracks,
                            selectedTrackCode: vm.focusedTrack?.trackCode,
                            onSelect: { vm.selectTrack($0) }
                        )
                    }

                    if !vm.microcycleDays.isEmpty {
                        DaySwitcher(
                            days: vm.microcycleDays,
                            selectedDate: vm.selectedDate,
                            todayISO: vm.todayISO,
                            onSelect: { vm.selectDate($0) }
                        )
                    }

                    if vm.showBridgeBadge {
                        BridgeWeekBadge()
                            .padding(.horizontal, Spacing.md)
                    }

                    heroSection
                        .padding(.horizontal, Spacing.md)

                    if !vm.microcycleDays.isEmpty {
                        WeekStrip(
                            days: vm.microcycleDays,
                            selectedDate: vm.selectedDate,
                            todayISO: vm.todayISO,
                            onSelect: { vm.selectDate($0) }
                        )
                    }

                    if vm.showSaturdayDrop, let banner = saturdayBanner {
                        banner
                            .padding(.horizontal, Spacing.md)
                    }

                    previousWeeksSection
                        .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.fbbBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await vm.refresh() }
        .task { await vm.onAppear() }
        .fullScreenCover(isPresented: $showLoggerPlaceholder) {
            LoggerPlaceholderView { showLoggerPlaceholder = false }
        }
    }

    // MARK: - Sections

    private var header: some View {
        GreetingHeader(
            weekdayName: ISODate.weekdayName(headerISO),
            monthDay: ISODate.monthDay(headerISO),
            microcycleLabel: microcycleLabel
        )
        .padding(.horizontal, Spacing.md)
    }

    private var headerISO: String {
        vm.selectedDate ?? vm.todayISO
    }

    private var microcycleLabel: String? {
        guard let micro = vm.focusedTrack?.microcycle else { return nil }
        var parts: [String] = []
        if let mesoPos = micro.mesocyclePositionHint {
            parts.append("Mesocycle \(mesoPos)")
        }
        if let weekPos = micro.weekPosition {
            parts.append("Week \(weekPos)")
        }
        if parts.isEmpty {
            parts.append(micro.kind.displayLabel)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var heroSection: some View {
        switch vm.dayDetail {
        case .idle, .loading:
            heroSkeleton

        case .loaded:
            if let day = vm.focusedDay, let track = vm.focusedTrack {
                if day.kind == .rest {
                    RestDayCard(day: day)
                } else {
                    WorkoutHeroCard(
                        day: day,
                        track: track,
                        onStart: { showLoggerPlaceholder = true }
                    )
                }
            } else {
                EmptyDayCard()
            }

        case .failed(let err):
            ErrorCard(
                title: "Couldn't load today's workout",
                message: err.errorDescription,
                isRetryable: err.isRetryable,
                retry: { Task { await vm.refresh() } }
            )
        }
    }

    private var heroSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SkeletonBlock(width: 180, height: 16)
            SkeletonBlock(width: 240, height: 24)
            SkeletonBlock(height: 14)
            SkeletonBlock(height: 14)
            SkeletonBlock(height: 52, corner: 12)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var previousWeeksSection: some View {
        switch vm.weekList {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Previous Weeks")
                    .font(.fbb.title3)
                    .foregroundStyle(.inkPrimary)
                ForEach(0..<3, id: \.self) { _ in WeekRow.skeleton() }
            }

        case .loaded(let rows):
            PreviousWeeksList(
                rows: rows,
                currentWeekStartsOn: vm.currentWeek.value?.weekStartsOn
            )

        case .failed(let err):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Previous Weeks")
                    .font(.fbb.title3)
                    .foregroundStyle(.inkPrimary)
                ErrorCard(
                    title: "Couldn't load history",
                    message: err.errorDescription,
                    isRetryable: err.isRetryable,
                    retry: { Task { await vm.refresh() } }
                )
            }
        }
    }

    @ViewBuilder
    private var saturdayBanner: SaturdayDropBanner? {
        guard case .loaded(let rows) = vm.weekList,
              let newest = rows.max(by: { $0.weekStartsOn < $1.weekStartsOn }) else {
            return nil
        }
        return SaturdayDropBanner(
            weekRangeLabel: ISODate.rangeLabel(start: newest.weekStartsOn, end: newest.weekEndsOn),
            onTap: { vm.selectDate(newest.weekStartsOn) }
        )
    }
}

// MARK: - Empty / placeholder views

private struct EmptyDayCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No workout for this day")
                .font(.fbb.bodyBold)
                .foregroundStyle(.inkPrimary)
            Text("Pick another day from the strip above.")
                .font(.fbb.caption)
                .foregroundStyle(.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct LoggerPlaceholderView: View {
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(.fbbOrange)
            Text("Logger coming next")
                .font(.fbb.title2)
                .foregroundStyle(.inkPrimary)
            Text("This is the .fullScreenCover where the workout logger will live.")
                .font(.fbb.body)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            Button("Close", action: onClose)
                .buttonStyle(PrimaryGlassButtonStyle())
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fbbBackground)
    }
}
