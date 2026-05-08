import SwiftUI

struct KPIStripCard: View {
    let values: [KPIValue]

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(values) { value in
                KPITile(value: value)
            }
        }
    }
}

private struct KPITile: View {
    let value: KPIValue

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: value.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stateTint)
                Text(value.label.uppercased())
                    .font(.byow.label)
                    .tracking(1.0)
                    .foregroundStyle(Color.inkSecondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                Text(value.value)
                    .font(.byow.metricLarge)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let detail = value.detail {
                    Text(detail)
                        .font(.byow.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if let delta = value.delta {
                Text(delta)
                    .font(.byow.caption.weight(.semibold))
                    .foregroundStyle(stateTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value.label): \(value.value) \(value.detail ?? "")\(value.delta.map { ", \($0)" } ?? "")")
    }

    private var stateTint: Color {
        switch value.state {
        case .gaining:  return .byowOrange
        case .onPlan:   return .byowTeal
        case .lagging:  return .semanticWarning
        case .neutral:  return .inkSecondary
        }
    }
}

#Preview {
    KPIStripCard(values: StatsMockData.kpis)
        .padding()
        .background(Color.byowBackground)
}
