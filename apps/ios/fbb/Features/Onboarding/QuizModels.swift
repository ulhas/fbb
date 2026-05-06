import Foundation

/// Phase-1 quiz that mimics FBB live's "find your match" flow. Four
/// questions; client-side recommendation. Lifted to a service when the
/// rules need to encode subscription / inventory / A-B logic.

enum QuizEquipment: String, CaseIterable, Hashable {
    case limited
    case varied

    var label: String {
        switch self {
        case .limited: return "Limited – DBs / Bench / Pull-Up Bar Only"
        case .varied:  return "Varied – Barbell / DBs or KBs / Typical Gym Setup"
        }
    }
}

enum QuizGoal: String, CaseIterable, Hashable {
    case lookGood
    case strongAndFit
    case improvePain
    case crossfit

    var label: String {
        switch self {
        case .lookGood:     return "Look good"
        case .strongAndFit: return "Get strong & fit"
        case .improvePain:  return "Improve pain"
        case .crossfit:     return "CrossFit performance"
        }
    }
}

enum QuizPreference: String, CaseIterable, Hashable {
    case liftingAndConditioning
    case liftingOnly

    var label: String {
        switch self {
        case .liftingAndConditioning: return "Lifting & Conditioning"
        case .liftingOnly:            return "Lifting Only"
        }
    }
}

enum QuizCadence: String, CaseIterable, Hashable {
    case x3, x4, x5

    var label: String {
        switch self {
        case .x3: return "3 days a week"
        case .x4: return "4 days a week"
        case .x5: return "5 days a week"
        }
    }

    /// The cadence fragment that appears in track codes (`pump_lift_4x` etc.).
    var codeFragment: String {
        switch self {
        case .x3: return "3x"
        case .x4: return "4x"
        case .x5: return "5x"
        }
    }
}

/// One step of the quiz. The result step is its own case so the sheet's
/// NavigationStack handles "next" uniformly — no special-case at the end.
enum QuizStep: Int, CaseIterable, Hashable {
    case equipment, goal, preference, cadence, result

    var ordinalLabel: String {
        switch self {
        case .equipment:  return "1 of 4"
        case .goal:       return "2 of 4"
        case .preference: return "3 of 4"
        case .cadence:    return "4 of 4"
        case .result:     return "Match"
        }
    }

    var next: QuizStep? {
        QuizStep(rawValue: rawValue + 1)
    }
}

struct QuizAnswers: Hashable {
    var equipment: QuizEquipment?
    var goal: QuizGoal?
    var preference: QuizPreference?
    var cadence: QuizCadence?

    func isComplete(through step: QuizStep) -> Bool {
        switch step {
        case .equipment:  return equipment != nil
        case .goal:       return goal != nil
        case .preference: return preference != nil
        case .cadence:    return cadence != nil
        case .result:     return equipment != nil && goal != nil && preference != nil && cadence != nil
        }
    }
}

/// One recommended track from the quiz. The result screen renders the
/// primary card big and the alternates as smaller chips so the user gets
/// a clear "this is the one" feeling without being trapped.
struct QuizRecommendation: Hashable, Identifiable {
    enum Kind: Hashable {
        case primary
        case alternate
    }
    var id: String { code }
    let code: String
    let track: TrackCatalogRow
    let kind: Kind
    let reason: String
}

enum QuizRecommender {
    /// Pick a primary track + 1-2 sensible alternates from the live catalog.
    /// Pure function over `(answers, catalog)` so the recommendation is
    /// reproducible and easy to lift to the backend later.
    static func recommend(
        from answers: QuizAnswers,
        catalog: [TrackCatalogRow]
    ) -> [QuizRecommendation] {
        guard let goal = answers.goal,
              let preference = answers.preference,
              let cadence = answers.cadence,
              let equipment = answers.equipment else {
            return []
        }

        let primaryCode: String
        let primaryReason: String

        if equipment == .limited {
            primaryCode = "minimalist"
            primaryReason = "Bodyweight + dumbbells. Built for gyms with the basics."
        } else if goal == .crossfit {
            primaryCode = "perform"
            primaryReason = "Competition-style mixed modal. Built to peak you for a sport."
        } else if goal == .improvePain {
            primaryCode = "minimalist"
            primaryReason = "Lower load, lower stress. Rebuild capacity without aggravation."
        } else if preference == .liftingOnly {
            primaryCode = "pump_lift_\(cadence.codeFragment)"
            primaryReason = "Pure strength split — heavy compounds and structured accessories."
        } else {
            primaryCode = "pump_condition_\(cadence.codeFragment)"
            primaryReason = "Strength + conditioning blended every week — capacity and lifting at the same time."
        }

        var picks: [QuizRecommendation] = []
        if let primary = catalog.first(where: { $0.code == primaryCode }) {
            picks.append(QuizRecommendation(
                code: primary.code,
                track: primary,
                kind: .primary,
                reason: primaryReason
            ))
        }

        // Up to two alternates — same family with adjacent cadence first,
        // then the opposite family at the chosen cadence. Skips the primary
        // and any tracks the user already follows.
        let alternateCodes = alternates(
            for: primaryCode,
            cadence: cadence,
            preference: preference
        )
        for code in alternateCodes {
            guard picks.count < 3,
                  picks.allSatisfy({ $0.code != code }),
                  let row = catalog.first(where: { $0.code == code && !$0.isFollowed }) else {
                continue
            }
            picks.append(QuizRecommendation(
                code: row.code,
                track: row,
                kind: .alternate,
                reason: alternateReason(for: row.code)
            ))
        }

        return picks
    }

    private static func alternates(
        for primary: String,
        cadence: QuizCadence,
        preference: QuizPreference
    ) -> [String] {
        if primary.hasPrefix("pump_lift") {
            // Same family adjacent cadence + sibling family same cadence.
            return adjacentCadences(cadence).map { "pump_lift_\($0.codeFragment)" }
                + ["pump_condition_\(cadence.codeFragment)"]
        }
        if primary.hasPrefix("pump_condition") {
            return adjacentCadences(cadence).map { "pump_condition_\($0.codeFragment)" }
                + ["pump_lift_\(cadence.codeFragment)"]
        }
        if primary == "perform" {
            return ["pump_condition_\(cadence.codeFragment)", "pump_lift_\(cadence.codeFragment)"]
        }
        if primary == "minimalist" {
            return ["pump_lift_3x", "pump_condition_3x"]
        }
        return []
    }

    private static func adjacentCadences(_ c: QuizCadence) -> [QuizCadence] {
        switch c {
        case .x3: return [.x4]
        case .x4: return [.x5, .x3]
        case .x5: return [.x4]
        }
    }

    private static func alternateReason(for code: String) -> String {
        if code.hasPrefix("pump_lift")      { return "Same idea, lifting-only focus." }
        if code.hasPrefix("pump_condition") { return "Adds conditioning to the same lifting backbone." }
        if code == "perform"                { return "Competition-style if you want to compete." }
        if code == "minimalist"             { return "Light kit, short sessions." }
        return "Worth a look."
    }
}
