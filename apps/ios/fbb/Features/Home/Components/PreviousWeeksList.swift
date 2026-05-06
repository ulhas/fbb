import SwiftUI

struct PreviousWeeksList: View {
    let rows: [TrainingWeekSummaryRow]
    let currentWeekStartsOn: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Previous Weeks")
                .font(.fbb.title3)
                .foregroundStyle(.inkPrimary)

            if visibleRows.isEmpty {
                Text("No history yet — your first weeks will appear here.")
                    .font(.fbb.caption)
                    .foregroundStyle(.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(visibleRows) { row in
                    NavigationLink(value: NavRoute.week(row.weekStartsOn)) {
                        WeekRow(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var visibleRows: [TrainingWeekSummaryRow] {
        rows
            .filter { $0.weekStartsOn != currentWeekStartsOn }
            .sorted(by: { $0.weekStartsOn > $1.weekStartsOn })
            .prefix(8)
            .map { $0 }
    }
}
