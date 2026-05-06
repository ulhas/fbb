import SwiftUI

/// Read-only browse of a single day across every track that scheduled it.
struct DayDetailView: View {
    let weekStartsOn: String
    let scheduledOn: String
    let api: APIClient

    @State private var detail: TrainingWeekDayDetailRow?
    @State private var error: APIError?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if let detail {
                    Text("\(ISODate.weekdayName(scheduledOn)) · \(ISODate.monthDay(scheduledOn))")
                        .font(.fbb.title2)
                        .foregroundStyle(.inkPrimary)
                        .padding(.horizontal, Spacing.md)

                    ForEach(detail.cells) { cell in
                        TrackDayCell(cell: cell)
                            .padding(.horizontal, Spacing.md)
                    }
                } else if let error {
                    ErrorCard(
                        title: "Couldn't load day",
                        message: error.errorDescription,
                        isRetryable: error.isRetryable,
                        retry: { Task { await load() } }
                    )
                    .padding(.horizontal, Spacing.md)
                } else {
                    SkeletonBlock(width: 200, height: 24)
                        .padding(.horizontal, Spacing.md)
                    SkeletonBlock(height: 220, corner: 16)
                        .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.fbbBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Day")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            detail = try await api.day(weekStartsOn: weekStartsOn, scheduledOn: scheduledOn)
            error = nil
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}

private struct TrackDayCell: View {
    let cell: TrainingWeekDayCellRow

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(cell.track.displayName)
                    .font(.fbb.caption)
                    .foregroundStyle(.inkMuted)
                if cell.track.microcycle.kind == .bridgeWeek {
                    BridgeWeekBadge()
                }
                Spacer(minLength: 0)
            }

            Text(cell.day.displayName)
                .font(.fbb.title3)
                .foregroundStyle(.inkPrimary)

            if cell.day.kind == .rest {
                Text("Rest day")
                    .font(.fbb.body)
                    .foregroundStyle(.inkSecondary)
            } else {
                ForEach(cell.day.sections) { section in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(section.letter)
                            .font(.fbb.title3)
                            .foregroundStyle(.fbbOrange)
                            .frame(width: 24, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.displayName)
                                .font(.fbb.bodyBold)
                            HStack(spacing: Spacing.xs) {
                                PrescriptionBadge(
                                    mode: section.prescriptionMode,
                                    durationMin: section.targetDurationMin,
                                    durationMax: section.targetDurationMax
                                )
                                Text("\(section.groups.flatMap(\.exercises).count) exercises")
                                    .font(.fbb.caption)
                                    .foregroundStyle(.inkMuted)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
