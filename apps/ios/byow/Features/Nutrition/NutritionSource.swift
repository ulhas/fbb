import Foundation

/// Abstract source of nutrition data. Phase 1 ships `MockNutritionSource`;
/// Phase 2 will bring `LiveNutritionSource` over `/nutrition/day/{date}`.
protocol NutritionSource: Sendable {
    func loadDay(date: String, forceRefresh: Bool) async throws -> NutritionDay
}

// MARK: - Mock implementation

struct MockNutritionSource: NutritionSource {
    let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    func loadDay(date: String, forceRefresh: Bool) async throws -> NutritionDay {
        try? await Task.sleep(for: .milliseconds(forceRefresh ? 320 : 160))
        return NutritionMockData.build(for: date, now: now)
    }
}

// MARK: - Mock builder

enum NutritionMockData {

    static func build(for date: String, now: Date) -> NutritionDay {
        let cal = Calendar.iso8601UTCFromNutrition
        let target = MacroTarget(kcal: 2_450, proteinG: 180, carbsG: 280, fatG: 78)

        let meals = mealsFor(date: date, now: now)
        let logged = totals(of: meals)

        return NutritionDay(
            date: date,
            target: target,
            logged: logged,
            meals: meals,
            coachLine: coachLine(for: date, now: now),
            recents: recents,
            savedMeals: savedMeals,
            weekly: weekly(now: now, target: target.kcal),
            consistency: MacroConsistency(
                proteinHits: 5,
                carbsHits: 4,
                fatHits: 6,
                total: 7,
                bestStreak: 9
            ),
            weight: StatsMockData.bodyWeight(now: now), // shared with Stats card
            insights: insights,
            dateStrip: dateStrip(now: now, selected: date),
            coachName: "Sarah"
        )
    }

    // MARK: Coach line — varies by selected day's "training context"

    private static func coachLine(for date: String, now: Date) -> String {
        let cal = Calendar.iso8601UTCFromNutrition
        guard let target = ISODate.parse(date) else {
            return "Pump Lift day · push protein to 200 g and front-load carbs pre-workout."
        }
        // Map day-of-week to a believable training context (mock).
        let weekday = cal.component(.weekday, from: target) // 1=Sunday...7=Saturday
        switch weekday {
        case 2, 5: // Mon, Thu
            return "Lower strength day · push protein to 200 g and front-load carbs pre-workout."
        case 3, 6: // Tue, Fri
            return "Upper hypertrophy day · steady protein, carbs to support volume."
        case 4:    // Wed
            return "Pump Condition day · keep carbs up, hydration is the lever."
        case 7:    // Sat
            return "Active recovery · same protein, lighter carbs. You've earned a calm one."
        case 1:    // Sun
            return "Rest day · same protein floor, take fat slightly higher if you're hungry."
        default:
            return "Steady macros today · protein floor first, fill the rest with what fits."
        }
    }

    // MARK: Meals — vary by date so the strip demos partial / complete / empty

    private static func mealsFor(date: String, now: Date) -> [LoggedMeal] {
        let cal = Calendar.iso8601UTCFromNutrition
        let today = ISODate.string(now)
        guard let target = ISODate.parse(date), let nowDay = ISODate.parse(today) else {
            return emptyMeals()
        }
        let days = cal.dateComponents([.day], from: target, to: nowDay).day ?? 0

        switch days {
        case 0:
            // Today: 3 meals logged, snacks empty
            return [
                LoggedMeal(kind: .breakfast, foods: breakfastFoods),
                LoggedMeal(kind: .lunch,     foods: lunchFoods),
                LoggedMeal(kind: .dinner,    foods: []),
                LoggedMeal(kind: .snack,     foods: snackFoods),
            ]
        case 1:
            // Yesterday: full day
            return [
                LoggedMeal(kind: .breakfast, foods: breakfastFoods),
                LoggedMeal(kind: .lunch,     foods: lunchFoods),
                LoggedMeal(kind: .dinner,    foods: dinnerFoods),
                LoggedMeal(kind: .snack,     foods: snackFoods),
            ]
        case 2, 3, 4:
            // Recent: partial
            return [
                LoggedMeal(kind: .breakfast, foods: breakfastFoods),
                LoggedMeal(kind: .lunch,     foods: lunchFoods),
                LoggedMeal(kind: .dinner,    foods: dinnerFoods),
                LoggedMeal(kind: .snack,     foods: []),
            ]
        case 5:
            // Empty day — to demo the empty state UI on the date strip
            return emptyMeals()
        default:
            // Older history: full
            return [
                LoggedMeal(kind: .breakfast, foods: breakfastFoods),
                LoggedMeal(kind: .lunch,     foods: lunchFoods),
                LoggedMeal(kind: .dinner,    foods: dinnerFoods),
                LoggedMeal(kind: .snack,     foods: snackFoods),
            ]
        }
    }

    private static func emptyMeals() -> [LoggedMeal] {
        MealKind.allCases.map { LoggedMeal(kind: $0, foods: []) }
    }

    private static func totals(of meals: [LoggedMeal]) -> MacroTotals {
        meals.reduce(MacroTotals.zero) { acc, meal in
            MacroTotals(
                kcal:     acc.kcal     + meal.totalKcal,
                proteinG: acc.proteinG + meal.totalProteinG,
                carbsG:   acc.carbsG   + meal.totalCarbsG,
                fatG:     acc.fatG     + meal.totalFatG
            )
        }
    }

    // MARK: Sample foods

    private static let breakfastFoods: [LoggedFood] = [
        LoggedFood(name: "Greek yogurt 5%", portion: "200 g",  kcal: 192, p: 16, c: 8,  f: 11),
        LoggedFood(name: "Banana",          portion: "1 med",  kcal: 105, p: 1,  c: 27, f: 0),
        LoggedFood(name: "Whey isolate",    portion: "1 scoop",kcal: 120, p: 25, c: 3,  f: 1),
    ]
    private static let lunchFoods: [LoggedFood] = [
        LoggedFood(name: "Chicken breast",  portion: "180 g",  kcal: 297, p: 56, c: 0,  f: 6),
        LoggedFood(name: "Jasmine rice",    portion: "1.5 cup",kcal: 308, p: 6,  c: 67, f: 1),
        LoggedFood(name: "Sautéed greens",  portion: "1 bowl", kcal: 80,  p: 3,  c: 9,  f: 4),
    ]
    private static let dinnerFoods: [LoggedFood] = [
        LoggedFood(name: "Sirloin steak",   portion: "200 g",  kcal: 414, p: 60, c: 0,  f: 18),
        LoggedFood(name: "Sweet potato",    portion: "250 g",  kcal: 215, p: 4,  c: 50, f: 0),
        LoggedFood(name: "Olive oil",       portion: "1 tbsp", kcal: 119, p: 0,  c: 0,  f: 14),
    ]
    private static let snackFoods: [LoggedFood] = [
        LoggedFood(name: "Cottage cheese",  portion: "150 g",  kcal: 125, p: 17, c: 5,  f: 4),
        LoggedFood(name: "Almonds",         portion: "20 g",   kcal: 116, p: 4,  c: 4,  f: 10),
    ]

    // MARK: Quick-add chips

    private static let recents: [FoodSuggestion] = [
        FoodSuggestion(label: "Greek yogurt 5%",   detail: "200 g · 192 kcal"),
        FoodSuggestion(label: "Whey isolate",      detail: "1 scoop · 120 kcal"),
        FoodSuggestion(label: "Chicken breast",    detail: "180 g · 297 kcal"),
        FoodSuggestion(label: "Jasmine rice",      detail: "1.5 cup · 308 kcal"),
        FoodSuggestion(label: "Cottage cheese",    detail: "150 g · 125 kcal"),
    ]

    private static let savedMeals: [FoodSuggestion] = [
        FoodSuggestion(label: "Post-workout shake", detail: "380 kcal · 42P/38C/6F"),
        FoodSuggestion(label: "Steak + sweet potato", detail: "748 kcal · 64P/50C/32F"),
        FoodSuggestion(label: "Yogurt bowl",          detail: "417 kcal · 42P/38C/12F"),
    ]

    // MARK: Weekly bars

    private static func weekly(now: Date, target: Int) -> [DailyCalories] {
        let cal = Calendar.iso8601UTCFromNutrition
        let kcals: [Int] = [2_310, 2_540, 2_410, 2_180, 2_460, 2_780, 2_390]
        return kcals.enumerated().map { (idx, k) in
            let d = cal.date(byAdding: .day, value: idx - (kcals.count - 1), to: now) ?? now
            let status: DailyCalories.Status = {
                let lower = Double(target) * 0.95
                let upper = Double(target) * 1.05
                if Double(k) < lower { return .under }
                if Double(k) > upper { return .over }
                return .hit
            }()
            return DailyCalories(date: ISODate.string(d), kcal: k, target: target, status: status)
        }
    }

    // MARK: Date strip

    private static func dateStrip(now: Date, selected: String) -> [DateStripDay] {
        let cal = Calendar.iso8601UTCFromNutrition
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: now) ?? now
            let iso = ISODate.string(d)
            let logState: DateStripDay.LogState
            switch offset {
            case 0:    logState = .partial   // today
            case 1...4: logState = .complete
            case 5:    logState = .untouched
            case 6:    logState = .complete
            default:   logState = .complete
            }
            return DateStripDay(
                date: iso,
                isToday: offset == 0,
                isSelected: iso == selected,
                logState: logState
            )
        }
    }

    // MARK: Insights — coach-tone, nutrition-flavored. Uses the same Insight
    // type as Stats so InsightCard can render them as-is.

    static let insights: [Insight] = [
        Insight(
            kind: .celebration,
            title: "Protein hit 5/7 days last week",
            body: "Your best streak this block. Bar speed correlates with protein adherence — keep pushing.",
            action: .share
        ),
        Insight(
            kind: .observation,
            title: "Saturday carbs spiked 40% over weekday avg",
            body: "That's recovery day — likely intentional. If you're trending down on weight, leave it.",
            action: .snooze
        ),
        Insight(
            kind: .opportunity,
            title: "Tuesday lifts under target by 250 kcal",
            body: "Last 3 weeks of Tuesday lift days averaged 250 kcal under target. Consider adding a 200 kcal pre-workout snack.",
            action: .openTrack(code: "pump_lift_4x")
        ),
    ]
}

// MARK: - Calendar helper

private extension Calendar {
    static var iso8601UTCFromNutrition: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }
}
