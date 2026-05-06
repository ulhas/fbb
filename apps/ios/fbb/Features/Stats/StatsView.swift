import SwiftUI

struct StatsView: View {
    @State private var vm: StatsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(userStore: UserStore) {
        _vm = State(wrappedValue: StatsViewModel(userStore: userStore))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                switch vm.overview {
                case .idle, .loading:
                    StatsSkeleton()
                        .transition(.opacity)
                case .failed(let error):
                    ErrorCard(
                        title: "Couldn't load your stats",
                        message: error.isRetryable ? "Pull to retry, or tap below." : nil,
                        isRetryable: error.isRetryable,
                        retry: { Task { await vm.refresh() } }
                    )
                case .loaded(let overview):
                    StatsContent(
                        overview: overview,
                        onRefreshHero: { await vm.refreshHero() }
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
            .animation(reduceMotion ? nil : Motion.standard, value: caseTag(vm.overview))
        }
        .scrollIndicators(.hidden)
        .background(Color.fbbBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let microcycle = vm.overview.value?.microcycle {
                    MicrocycleChip(context: microcycle)
                }
            }
        }
        .refreshable { await vm.refresh() }
        .task { await vm.onAppear() }
    }

    /// Lets `.animation(_:value:)` notice case transitions without needing the
    /// payload to be `Equatable`.
    private func caseTag<V>(_ s: StatsViewModel.LoadState<V>) -> Int {
        switch s {
        case .idle:    return 0
        case .loading: return 1
        case .loaded:  return 2
        case .failed:  return 3
        }
    }
}

// MARK: - Loaded content

private struct StatsContent: View {
    let overview: StatsOverview
    let onRefreshHero: () async -> Void

    @State private var showWhySheet = false

    var body: some View {
        Group {
            HeroInsightCard(
                insight: overview.hero,
                onRefresh: onRefreshHero,
                onWhy: { showWhySheet = true }
            )

            KPIStripCard(values: overview.kpis)

            TrackProgressionStrip(tracks: overview.tracks)

            MovementBalanceCard(slices: overview.balance)

            VolumeTrendCard(points: overview.trend)

            RecoveryHealthCard(snapshot: overview.recovery)

            PRFeedCard(prs: overview.prs)

            AdherenceHeatmapCard(cells: overview.heatmap, onTap: { _ in })

            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Coach insights", subtitle: "What to act on this week")
                ForEach(overview.insights) { insight in
                    InsightCard(insight: insight, onAction: { _ in })
                }
            }

            Text("How are these stats calculated?")
                .font(.fbb.caption.weight(.semibold))
                .foregroundStyle(Color.fbbTeal)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.lg)
        }
        .sheet(isPresented: $showWhySheet) {
            WhyThisReadSheet(insight: overview.hero, microcycle: overview.microcycle)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Why-this-read explainer

private struct WhyThisReadSheet: View {
    let insight: HeroInsight
    let microcycle: MicrocycleContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Why this read?")
                    .font(.fbb.title2)
                    .foregroundStyle(Color.inkPrimary)

                Text("This is generated from your last 4 weeks of training: completed sessions, prescribed vs. logged volume, RPE compliance, sleep, and where you are in the program. Right now you're in the **\(microcycle.summary)** of your current mesocycle, so the read leans on what matters in this phase.")
                    .font(.fbb.body)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(3)

                Divider().background(Color.fbbDivider)

                Text("THE READ")
                    .font(.fbb.label).tracking(1.2)
                    .foregroundStyle(Color.inkSecondary)

                Text(insight.body)
                    .font(.fbb.body)
                    .foregroundStyle(Color.inkPrimary)
                    .lineSpacing(3)

                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
        }
        .background(Color.fbbBackground.ignoresSafeArea())
    }
}

// MARK: - Loading skeleton

private struct StatsSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SkeletonBlock(width: 100, height: 11)
                SkeletonBlock(height: 16)
                SkeletonBlock(height: 16)
                SkeletonBlock(width: 220, height: 16)
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner))
            .elevation(.card)

            HStack(spacing: Spacing.sm) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 60, height: 9)
                        SkeletonBlock(width: 80, height: 28)
                        SkeletonBlock(width: 100, height: 11)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner))
                    .elevation(.card)
                }
            }

            VStack(spacing: Spacing.sm) {
                SkeletonBlock(height: 90)
                SkeletonBlock(height: 180)
                SkeletonBlock(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        StatsView(userStore: UserStore(api: APIClient()))
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
    }
}
