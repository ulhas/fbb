import Foundation

// MARK: - Top-level day

/// Everything the Nutrition tab renders for one date. Phase 1 ships from
/// `MockNutritionSource`; Phase 2 will be `LiveNutritionSource` over
/// `/nutrition/day/{date}` once `food_log_entries` reads exist.
struct NutritionDay: Sendable {
    let date: String           // ISO YYYY-MM-DD
    let target: MacroTarget
    let logged: MacroTotals
    let meals: [LoggedMeal]
    let coachLine: String
    let recents: [FoodSuggestion]
    let savedMeals: [FoodSuggestion]
    let weekly: [DailyCalories]
    let consistency: MacroConsistency
    let weight: BodyWeightTrend  // shared with Stats Recovery card
    let insights: [Insight]      // reused from Stats
    let dateStrip: [DateStripDay]
    let coachName: String?
}

// MARK: - Targets & totals

struct MacroTarget: Sendable, Hashable {
    let kcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
}

struct MacroTotals: Sendable, Hashable {
    let kcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    static let zero = MacroTotals(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)
}

// MARK: - Meals

enum MealKind: String, Sendable, Hashable, CaseIterable {
    case breakfast, lunch, dinner, snack

    var displayLabel: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.fill"
        case .snack:     return "leaf.fill"
        }
    }
}

struct LoggedMeal: Sendable, Identifiable {
    var id: MealKind { kind }
    let kind: MealKind
    let foods: [LoggedFood]

    var totalKcal: Int       { foods.reduce(0) { $0 + $1.kcal } }
    var totalProteinG: Int   { foods.reduce(0) { $0 + $1.proteinG } }
    var totalCarbsG: Int     { foods.reduce(0) { $0 + $1.carbsG } }
    var totalFatG: Int       { foods.reduce(0) { $0 + $1.fatG } }
    var isEmpty: Bool        { foods.isEmpty }
}

struct LoggedFood: Sendable, Identifiable {
    let id: UUID
    let name: String
    let portion: String
    let kcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    init(name: String, portion: String, kcal: Int, p: Int, c: Int, f: Int) {
        self.id = UUID()
        self.name = name
        self.portion = portion
        self.kcal = kcal
        self.proteinG = p
        self.carbsG = c
        self.fatG = f
    }
}

// MARK: - Quick-add suggestions

struct FoodSuggestion: Sendable, Identifiable {
    let id: UUID
    let label: String
    let detail: String   // "150g · 130 kcal" or "380 kcal · 42P/38C/6F"

    init(label: String, detail: String) {
        self.id = UUID()
        self.label = label
        self.detail = detail
    }
}

// MARK: - Weekly trend

struct DailyCalories: Sendable, Identifiable {
    enum Status: Sendable { case under, hit, over }

    var id: String { date }
    let date: String        // ISO YYYY-MM-DD
    let kcal: Int
    let target: Int
    let status: Status
}

// MARK: - Consistency

struct MacroConsistency: Sendable, Hashable {
    let proteinHits: Int    // out of `total`
    let carbsHits: Int
    let fatHits: Int
    let total: Int          // typically 7
    let bestStreak: Int
}

// MARK: - Date strip

struct DateStripDay: Sendable, Identifiable {
    enum LogState: Sendable { case untouched, partial, complete, future }

    var id: String { date }
    let date: String           // ISO YYYY-MM-DD
    let isToday: Bool
    let isSelected: Bool
    let logState: LogState
}
