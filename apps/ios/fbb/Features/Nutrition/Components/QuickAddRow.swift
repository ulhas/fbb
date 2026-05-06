import SwiftUI

struct QuickAddRow: View {
    let recents: [FoodSuggestion]
    let savedMeals: [FoodSuggestion]
    let onAction: (QuickAddAction) -> Void

    enum QuickAddAction {
        case photo
        case barcode
        case search
        case logFood(FoodSuggestion)
        case logMeal(FoodSuggestion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Quick add")
                .font(.fbb.label)
                .tracking(1.0)
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ActionChip(symbol: "camera.fill",         label: "Photo")   { onAction(.photo) }
                    ActionChip(symbol: "barcode.viewfinder",  label: "Barcode") { onAction(.barcode) }
                    ActionChip(symbol: "magnifyingglass",     label: "Search")  { onAction(.search) }

                    if !recents.isEmpty {
                        Divider()
                            .frame(height: 28)
                            .background(Color.fbbDivider)
                            .padding(.horizontal, Spacing.xxs)
                    }

                    ForEach(recents) { food in
                        SuggestionChip(suggestion: food, accent: .fbbOrange) {
                            onAction(.logFood(food))
                        }
                    }

                    if !savedMeals.isEmpty {
                        Divider()
                            .frame(height: 28)
                            .background(Color.fbbDivider)
                            .padding(.horizontal, Spacing.xxs)
                    }

                    ForEach(savedMeals) { meal in
                        SuggestionChip(suggestion: meal, accent: .fbbTeal, leadingSymbol: "tray.fill") {
                            onAction(.logMeal(meal))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct ActionChip: View {
    let symbol: String
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.fbb.caption.weight(.semibold))
            }
            .foregroundStyle(Color.fbbOrange)
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(Color.fbbOrangeTint.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SuggestionChip: View {
    let suggestion: FoodSuggestion
    let accent: Color
    var leadingSymbol: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let leadingSymbol {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.label)
                        .font(.fbb.caption.weight(.semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text(suggestion.detail)
                        .font(.fbb.label)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(Color.surfaceCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.fbbDivider, lineWidth: 0.5)
            )
            .accessibilityLabel("Log \(suggestion.label), \(suggestion.detail)")
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let day = NutritionMockData.build(for: ISODate.string(Date()), now: Date())
    return QuickAddRow(
        recents: day.recents,
        savedMeals: day.savedMeals,
        onAction: { _ in }
    )
    .padding(.vertical)
    .background(Color.fbbBackground)
}
