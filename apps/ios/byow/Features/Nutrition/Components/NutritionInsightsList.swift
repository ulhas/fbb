import SwiftUI

/// Reuses the Stats `InsightCard` so visual rhythm matches across pages.
struct NutritionInsightsList: View {
    let insights: [Insight]
    let onAction: (Insight, Insight.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.byowTeal)
                Text("Coach insights")
                    .font(.byow.title3)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 2)

            ForEach(insights) { insight in
                InsightCard(insight: insight, onAction: { action in onAction(insight, action) })
            }
        }
    }
}

#Preview {
    NutritionInsightsList(
        insights: NutritionMockData.insights,
        onAction: { _, _ in }
    )
    .padding()
    .background(Color.byowBackground)
}
