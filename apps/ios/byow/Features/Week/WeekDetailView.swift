import SwiftUI

/// Read-only browse of a previous (or current) week. Loads the slim
/// per-week index and lets the user drill into any day.
struct WeekDetailView: View {
    let weekStartsOn: String
    let api: APIClient

    @State private var detail: TrainingWeekDetailRow?
    @State private var error: APIError?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if let detail {
                    Text(ISODate.rangeLabel(start: detail.weekStartsOn, end: detail.weekEndsOn))
                        .font(.byow.title2)
                        .foregroundStyle(.inkPrimary)
                        .padding(.horizontal, Spacing.md)

                    ForEach(detail.tracks) { track in
                        TrackBlock(track: track, weekStartsOn: detail.weekStartsOn)
                    }
                } else if let error {
                    ErrorCard(
                        title: "Couldn't load week",
                        message: error.errorDescription,
                        isRetryable: error.isRetryable,
                        retry: { Task { await load() } }
                    )
                    .padding(.horizontal, Spacing.md)
                } else {
                    skeleton
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.byowBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Week")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBlock(width: 160, height: 22)
                .padding(.horizontal, Spacing.md)
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SkeletonBlock(width: 120, height: 14)
                    SkeletonBlock(height: 64, corner: 16)
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await api.week(weekStartsOn)
            error = nil
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}

private struct TrackBlock: View {
    let track: TrainingWeekTrackIndexRow
    let weekStartsOn: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(track.displayName)
                    .font(.byow.title3)
                    .foregroundStyle(.inkPrimary)
                if track.microcycle.kind == .bridgeWeek {
                    BridgeWeekBadge()
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(track.days) { day in
                    NavigationLink(value: NavRoute.workout(
                        trackCode: track.trackCode,
                        week: weekStartsOn,
                        day: day.scheduledOn
                    )) {
                        DayMetaRow(day: day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

private struct DayMetaRow: View {
    let day: TrainingWeekDayMetaRow

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(ISODate.weekdayName(day.scheduledOn)) · \(ISODate.monthDay(day.scheduledOn))")
                    .font(.byow.caption)
                    .foregroundStyle(.inkMuted)
                Text(day.displayName)
                    .font(.byow.bodyBold)
                    .foregroundStyle(.inkPrimary)
            }
            Spacer(minLength: 0)
            Text(day.kind == .rest ? "Rest" : "\(day.exerciseCount) ex.")
                .font(.byow.mono)
                .foregroundStyle(.inkSecondary)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
