import SwiftUI

struct MealSection: View {
    let meal: LoggedMeal
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header — present whether logged or empty
            HStack(spacing: Spacing.xs) {
                Image(systemName: meal.kind.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.byowOrange)
                    .frame(width: 24, height: 24)
                    .background(Color.byowOrangeTint.opacity(0.55), in: Circle())

                Text(meal.kind.displayLabel)
                    .font(.byow.bodyBold)
                    .foregroundStyle(Color.inkPrimary)

                Spacer(minLength: Spacing.xs)

                if !meal.isEmpty {
                    Text("\(meal.totalKcal) kcal")
                        .font(.byow.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .monospacedDigit()
                }

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.byowOrange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to \(meal.kind.displayLabel)")
            }
            .padding(.horizontal, 2)

            if meal.isEmpty {
                emptyRow
            } else {
                populatedCard
            }
        }
    }

    private var emptyRow: some View {
        HStack {
            Text("Tap + to log \(meal.kind.displayLabel.lowercased())")
                .font(.byow.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.md)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var populatedCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(meal.foods.enumerated()), id: \.element.id) { (idx, food) in
                MealFoodRow(food: food)
                if idx < meal.foods.count - 1 {
                    Divider()
                        .background(Color.byowDivider)
                        .padding(.leading, Spacing.md)
                }
            }
            Divider()
                .background(Color.byowDivider)
                .padding(.leading, Spacing.md)
            // Totals strip
            HStack(spacing: Spacing.md) {
                Spacer()
                TotalChip(label: "P", value: meal.totalProteinG, tint: .byowOrange)
                TotalChip(label: "C", value: meal.totalCarbsG,   tint: .byowTeal)
                TotalChip(label: "F", value: meal.totalFatG,     tint: .inkSecondary)
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.md)
        }
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCorner, style: .continuous))
        .elevation(.card)
    }
}

private struct TotalChip: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(.byow.label).foregroundStyle(tint)
            Text("\(value)g").font(.byow.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Color.inkSecondary)
        }
    }
}

#Preview {
    let day = NutritionMockData.build(for: ISODate.string(Date()), now: Date())
    return ScrollView {
        VStack(spacing: 16) {
            ForEach(day.meals) { meal in
                MealSection(meal: meal, onAdd: {})
            }
        }
        .padding()
    }
    .background(Color.byowBackground)
}
