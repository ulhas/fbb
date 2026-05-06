import Foundation

/// Abstract source of stats data. Phase 1 ships `MockStatsSource`; Phase 2
/// will bring `LiveStatsSource` once the backend exposes `/stats/overview`.
protocol StatsSource: Sendable {
    func loadOverview(forceRefresh: Bool) async throws -> StatsOverview
}

// MARK: - Mock implementation

/// Deterministic mock so the page doesn't shuffle on every cold-start, but
/// `forceRefresh` rotates the hero narrative to make pull-to-refresh feel
/// alive. Track progressions are scoped to whatever the user has enrolled
/// via `UserStore` so the page reads naturally for any seed.
struct MockStatsSource: StatsSource {
    let enrolledTrackCodes: [String]
    let now: Date
    private let heroIndex: Int

    init(
        enrolledTrackCodes: [String],
        now: Date = Date(),
        heroIndex: Int = 0
    ) {
        self.enrolledTrackCodes = enrolledTrackCodes
        self.now = now
        self.heroIndex = heroIndex
    }

    func loadOverview(forceRefresh: Bool) async throws -> StatsOverview {
        // Tiny artificial delay so loading skeletons get a chance to shine.
        try? await Task.sleep(for: .milliseconds(forceRefresh ? 350 : 180))

        let nextHero = forceRefresh ? heroIndex + 1 : heroIndex
        return StatsMockData.build(
            enrolledTrackCodes: enrolledTrackCodes.isEmpty ? ["pump_lift_4x"] : enrolledTrackCodes,
            now: now,
            heroIndex: nextHero
        )
    }
}

// MARK: - Mock data builder

enum StatsMockData {

    static func build(
        enrolledTrackCodes: [String],
        now: Date,
        heroIndex: Int
    ) -> StatsOverview {
        StatsOverview(
            microcycle: microcycle,
            hero: heroes[heroIndex % heroes.count],
            kpis: kpis,
            tracks: tracks(for: enrolledTrackCodes),
            balance: balance,
            trend: trend(now: now),
            recovery: recovery(now: now),
            prs: prs(now: now),
            heatmap: heatmap(now: now),
            insights: insights
        )
    }

    // MARK: Recovery & Health snapshot

    static func recovery(now: Date) -> RecoverySnapshot {
        RecoverySnapshot(
            sleep: HealthMetric(
                label: "Sleep",
                value: "7h 02m",
                unit: nil,
                symbol: "bed.double.fill",
                spark: [7.4, 7.1, 6.8, 7.6, 6.2, 6.9, 7.0],
                deltaLabel: "↓ 32m vs last week",
                state: .lagging
            ),
            hrv: HealthMetric(
                label: "HRV",
                value: "48",
                unit: "ms",
                symbol: "waveform.path.ecg",
                spark: [44, 46, 47, 45, 49, 50, 48],
                deltaLabel: "steady",
                state: .onPlan
            ),
            restingHR: HealthMetric(
                label: "Resting HR",
                value: "56",
                unit: "bpm",
                symbol: "heart.fill",
                spark: [58, 57, 58, 56, 55, 56, 56],
                deltaLabel: "↓ 2 bpm",
                state: .gaining
            ),
            steps: HealthMetric(
                label: "Steps",
                value: "8,400",
                unit: nil,
                symbol: "figure.walk",
                spark: [9100, 7200, 8800, 6400, 9800, 8600, 8400],
                deltaLabel: "avg · 7d",
                state: .neutral
            ),
            weight: bodyWeight(now: now),
            lastSyncedAt: now.addingTimeInterval(-12 * 60)
        )
    }

    static func bodyWeight(now: Date) -> BodyWeightTrend {
        let cal = Calendar.iso8601UTCFromStats
        // 30-day mock: starts at 184.4, drifts down with realistic daily noise.
        let raw: [Double] = [
            184.4, 184.6, 184.2, 184.0, 183.8, 184.1, 183.6, 183.4,
            183.7, 183.2, 183.0, 183.4, 182.9, 182.6, 182.8, 182.4,
            182.2, 182.5, 182.0, 181.8, 181.6, 181.9, 181.4, 181.2,
            181.0, 181.3, 180.8, 180.6, 180.9, 180.4
        ]
        let points = raw.enumerated().map { (idx, lb) -> WeightPoint in
            let d = cal.date(byAdding: .day, value: idx - (raw.count - 1), to: now) ?? now
            return WeightPoint(date: ISODate.string(d), weightLb: lb)
        }
        // Compute 4-week trend from first to last sample.
        let delta = (raw.last ?? 0) - (raw.first ?? 0)
        let arrow = delta < 0 ? "↓" : (delta > 0 ? "↑" : "·")
        let label = String(format: "%@ %.1f lb · 4-week avg", arrow, abs(delta))
        return BodyWeightTrend(points: points, trendLabel: label)
    }

    // MARK: Microcycle context

    static let microcycle = MicrocycleContext(
        kind: .standard,
        intent: .strength,
        weekPosition: 3,
        weekTotal: 5
    )

    // MARK: Hero variants

    static let heroes: [HeroInsight] = [
        HeroInsight(
            id: UUID(),
            body: "Strong week. You hit 5 of 6 prescribed sessions and pushed your Front Squat 3RM to 245 lb — a 15 lb jump from last block. Avg RPE landed at 7.4 on prescribed 7-8, so you're driving load without overshooting. One watch-out: hinge volume is 23% under plan. Pin down a deadlift session before Sunday and you close the loop on this microcycle clean.",
            signature: "Coach Read",
            generatedAt: Date().addingTimeInterval(-7_200) // 2h ago
        ),
        HeroInsight(
            id: UUID(),
            body: "Reading the last 14 days: your Pump Lift work is dialed — bar speeds steady at 80% working weight, RPE compliant. But Pump Condition is two sessions behind, and that's where the conditioning gains hide. If you make Wednesday a PC day, you'd close the gap before Mesocycle 3 ends. Keep sleep above 7h — your two highest-effort days followed your best sleep nights.",
            signature: "Coach Read",
            generatedAt: Date().addingTimeInterval(-7_200)
        ),
        HeroInsight(
            id: UUID(),
            body: "Mesocycle 3, week 3 — and you're cooking. Volume is up 8% week-over-week, three new PRs in the last 14 days, and adherence climbed from 67% to 83%. The pattern that stands out: your strongest sessions are landing on Tuesday and Friday. Protect those slots, treat Saturday as a buffer, and let next week's bridge week absorb the fatigue. Don't over-test before the deload.",
            signature: "Coach Read",
            generatedAt: Date().addingTimeInterval(-7_200)
        )
    ]

    // MARK: KPIs

    static let kpis: [KPIValue] = [
        KPIValue(
            label: "Adherence",
            value: "5/6",
            detail: "days",
            delta: "↑ from 4/6",
            state: .gaining,
            symbol: "checkmark.seal.fill"
        ),
        KPIValue(
            label: "Volume",
            value: "32.4k",
            detail: "lb · this week",
            delta: "↑ 8%",
            state: .gaining,
            symbol: "scalemass.fill"
        ),
        KPIValue(
            label: "Avg RPE",
            value: "7.4",
            detail: "on plan 7–8",
            delta: "✓ on plan",
            state: .onPlan,
            symbol: "gauge.medium"
        ),
        KPIValue(
            label: "PRs · block",
            value: "3",
            detail: "new",
            delta: "Front Squat · DL · Press",
            state: .gaining,
            symbol: "trophy.fill"
        )
    ]

    // MARK: Tracks

    static func tracks(for enrolledCodes: [String]) -> [TrackProgression] {
        let allMock: [(code: String, name: String, family: TrackFamily, intent: MesocycleIntent, sparkline: [Double], mover: String)] = [
            ("pump_lift_4x", "Pump Lift 4x", .pumpLift, .strength,
             [22_400, 24_100, 23_800, 26_200, 25_400, 27_900, 30_100, 32_400],
             "+15 lb 3RM Front Squat"),
            ("pump_condition_4x", "Pump Condition 4x", .pumpCondition, .conditioning,
             [12_800, 13_400, 13_100, 14_600, 13_900, 12_200, 11_800, 13_600],
             "Best mile pace 6:42"),
            ("perform_5x", "Perform 5x", .perform, .mixed,
             [28_200, 29_400, 31_100, 30_800, 32_600, 33_900, 34_500, 36_100],
             "+10 lb Snatch"),
            ("minimalist_3x", "Minimalist 3x", .minimalist, .hypertrophy,
             [15_600, 16_400, 16_900, 17_400, 18_100, 18_900, 19_700, 20_400],
             "+8 lb DB Row"),
            ("hybrid_running_4x", "Hybrid Running 4x", .hybridRunning, .conditioning,
             [18_100, 19_200, 20_400, 21_100, 22_600, 23_200, 24_400, 25_100],
             "10K PR 47:12"),
        ]

        // If the user has nothing enrolled, show the dev-default.
        let codes = enrolledCodes.isEmpty ? ["pump_lift_4x"] : enrolledCodes
        let focused = codes.first

        // Show enrolled tracks first, then a couple more for browse-feel.
        let enrolled: [TrackProgression] = codes.enumerated().compactMap { (idx, code) in
            guard let mock = allMock.first(where: { $0.code == code }) else { return nil }
            return TrackProgression(
                trackCode: mock.code,
                displayName: mock.name,
                family: mock.family,
                intent: mock.intent,
                weekPosition: 3,
                weekTotal: 5,
                sparkline: mock.sparkline,
                topMover: mock.mover,
                isFocused: code == focused
            )
        }

        let extra: [TrackProgression] = allMock
            .filter { mock in !codes.contains(mock.code) }
            .prefix(2)
            .map { mock in
                TrackProgression(
                    trackCode: mock.code,
                    displayName: mock.name,
                    family: mock.family,
                    intent: mock.intent,
                    weekPosition: 3,
                    weekTotal: 5,
                    sparkline: mock.sparkline,
                    topMover: mock.mover,
                    isFocused: false
                )
            }

        return enrolled + extra
    }

    // MARK: Movement balance (last 14 days)

    static let balance: [MovementBalanceSlice] = [
        MovementBalanceSlice(pattern: "Squat",          sets: 38, percent: 0.18),
        MovementBalanceSlice(pattern: "Hinge",          sets: 22, percent: 0.10, isFlagged: true),
        MovementBalanceSlice(pattern: "Push Horizontal",sets: 32, percent: 0.15),
        MovementBalanceSlice(pattern: "Push Vertical",  sets: 24, percent: 0.11),
        MovementBalanceSlice(pattern: "Pull Horizontal",sets: 30, percent: 0.14),
        MovementBalanceSlice(pattern: "Pull Vertical",  sets: 28, percent: 0.13),
        MovementBalanceSlice(pattern: "Carry",          sets: 12, percent: 0.06),
        MovementBalanceSlice(pattern: "Conditioning",   sets: 28, percent: 0.13),
    ]

    // MARK: Volume trend (last 12 weeks)

    static func trend(now: Date) -> [VolumePoint] {
        // Realistic weekly progression with a deload at week 8.
        let cal = Calendar.iso8601UTCFromStats
        let startOfThisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        let weeks: [(volume: Double, kind: MicrocycleKind, isPR: Bool)] = [
            (22_400, .standard,    false),
            (24_100, .standard,    false),
            (23_800, .standard,    true),   // PR week
            (26_200, .standard,    false),
            (25_400, .standard,    false),
            (27_900, .standard,    true),
            (30_100, .standard,    false),
            (16_800, .deload,      false),  // deload
            (28_400, .standard,    false),
            (30_900, .standard,    true),
            (32_700, .standard,    false),
            (32_400, .standard,    false),  // current
        ]

        return weeks.enumerated().map { (idx, w) in
            let weekStart = cal.date(byAdding: .weekOfYear, value: idx - (weeks.count - 1), to: startOfThisWeek) ?? now
            return VolumePoint(
                weekStartsOn: ISODate.string(weekStart),
                volumeLb: w.volume,
                microcycleKind: w.kind,
                isPRWeek: w.isPR
            )
        }
    }

    // MARK: PR feed

    static func prs(now: Date) -> [PRRecord] {
        let cal = Calendar.iso8601UTCFromStats
        func iso(daysAgo: Int) -> String {
            let d = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return ISODate.string(d)
        }
        return [
            PRRecord(movement: "Front Squat",  repMax: 3, weightLb: 245, achievedOn: iso(daysAgo: 6),  deltaLb: 15),
            PRRecord(movement: "Trap Bar Deadlift", repMax: 5, weightLb: 365, achievedOn: iso(daysAgo: 11), deltaLb: 20),
            PRRecord(movement: "Strict Press", repMax: 1, weightLb: 165, achievedOn: iso(daysAgo: 18), deltaLb: 5),
            PRRecord(movement: "DB Row",       repMax: 8, weightLb: 95,  achievedOn: iso(daysAgo: 22), deltaLb: 10),
            PRRecord(movement: "Snatch",       repMax: 1, weightLb: 175, achievedOn: iso(daysAgo: 32), deltaLb: 10),
        ]
    }

    // MARK: Adherence heatmap (last 90 days)

    static func heatmap(now: Date) -> [AdherenceCell] {
        let cal = Calendar.iso8601UTCFromStats
        // Weighted distribution that yields a believable adherence story.
        let pattern: [AdherenceCell.Status] = [
            .completed, .completed, .exceeded, .completed, .missed,
            .completed, .rest, .completed, .completed, .skipped,
            .completed, .exceeded, .completed, .rest, .missed,
            .completed, .completed, .exceeded, .skipped, .rest,
            .completed, .completed, .completed, .completed, .missed,
            .rest, .completed, .exceeded, .completed, .completed,
        ]
        return (0..<90).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: now) ?? now
            let iso = ISODate.string(date)
            let status: AdherenceCell.Status
            if offset == 0 {
                status = .future
            } else {
                status = pattern[(89 - offset) % pattern.count]
            }
            return AdherenceCell(date: iso, status: status)
        }
    }

    // MARK: Insights

    static let insights: [Insight] = [
        Insight(
            kind: .warning,
            title: "Bar speed declining on Front Squat",
            body: "Your top sets at 80% working weight have slowed 12% over the last 3 sessions. Either pull 5–10% off the bar today, or let the bridge week absorb it.",
            action: .viewSession(date: "2026-05-02")
        ),
        Insight(
            kind: .opportunity,
            title: "Pump Condition track is 2 sessions behind",
            body: "Your last PC day was 10 days ago. Slot Wednesday as a PC day this week and you close the gap before Mesocycle 3 ends.",
            action: .openTrack(code: "pump_condition_4x")
        ),
        Insight(
            kind: .observation,
            title: "Sleep average dropped 32 minutes",
            body: "Last 7 days averaged 6h 48m. Your two highest RPE days followed your two worst sleep nights. Worth defending tonight.",
            action: .snooze
        ),
        Insight(
            kind: .celebration,
            title: "New PR: Front Squat 3RM at 245 lb",
            body: "That's +15 lb over your prior 3RM in Mesocycle 2. Bar path looked clean — share the rep?",
            action: .share
        ),
        Insight(
            kind: .opportunity,
            title: "Bridge Week starts Monday",
            body: "Prescribed RPE drops to 6 across all sets. Treat it as a re-load, not a coast week — sharper movement, lighter load.",
            action: .dismiss
        ),
    ]
}

// MARK: - Calendar helper

private extension Calendar {
    /// Local UTC ISO calendar — kept private to avoid colliding with anywhere
    /// else in the app that may already have a similar helper.
    static var iso8601UTCFromStats: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }
}
