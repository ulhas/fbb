import SwiftUI

struct PRFeedCard: View {
    let prs: [PRRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Personal records", subtitle: "Last \(prs.count) lifts")

            VStack(spacing: 0) {
                ForEach(Array(prs.enumerated()), id: \.element.id) { (idx, pr) in
                    PRRow(record: pr)
                    if idx < prs.count - 1 {
                        Divider()
                            .background(Color.byowDivider)
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
            .elevation(.card)
        }
    }
}

private struct PRRow: View {
    let record: PRRecord

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.byowOrangeTint.opacity(0.55))
                    .frame(width: 38, height: 38)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.byowOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.movement)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text("\(record.repMaxLabel) · \(ISODate.monthDay(record.achievedOn))")
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(record.weightLb)) lb")
                    .font(.byow.metric)
                    .foregroundStyle(Color.inkPrimary)
                if let delta = record.deltaLb, delta != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(Int(delta)) lb")
                            .font(.byow.caption.monospacedDigit())
                    }
                    .foregroundStyle(Color.semanticSuccess)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PRFeedCard(prs: StatsMockData.prs(now: Date()))
        .padding()
        .background(Color.byowBackground)
}
