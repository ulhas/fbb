import SwiftUI

struct MealFoodRow: View {
    let food: LoggedFood

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.byow.body)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(food.portion)
                    .font(.byow.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(food.kcal) kcal")
                    .font(.byow.metric)
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                MacroBars(p: food.proteinG, c: food.carbsG, f: food.fatG)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(food.name), \(food.portion). \(food.kcal) kilocalories. \(food.proteinG) protein, \(food.carbsG) carbs, \(food.fatG) fat.")
    }
}

private struct MacroBars: View {
    let p: Int
    let c: Int
    let f: Int

    var body: some View {
        HStack(spacing: 6) {
            MacroBar(label: "P", value: p, tint: .byowOrange)
            MacroBar(label: "C", value: c, tint: .byowTeal)
            MacroBar(label: "F", value: f, tint: .inkSecondary)
        }
    }
}

private struct MacroBar: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.byow.label)
                .foregroundStyle(tint)
            Text("\(value)g")
                .font(.byow.label.monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        MealFoodRow(food: LoggedFood(name: "Greek yogurt 5%", portion: "200 g", kcal: 192, p: 16, c: 8, f: 11))
        Divider()
        MealFoodRow(food: LoggedFood(name: "Chicken breast", portion: "180 g", kcal: 297, p: 56, c: 0, f: 6))
    }
    .background(Color.surfaceCard)
    .padding()
    .background(Color.byowBackground)
}
