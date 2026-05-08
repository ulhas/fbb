import Foundation

// MARK: - Top-level profile

struct ProfileData: Sendable {
    let user: UserHeader
    let subscription: SubscriptionStatus
    let body: BodyProfile
    let account: AccountInfo
    let coach: CoachAssignment?
    let notifications: NotificationPrefs
    let privacy: PrivacyPrefs
    let appInfo: AppInfo
}

// MARK: - User header

struct UserHeader: Sendable, Hashable {
    let firstName: String
    let lastName: String
    let email: String
    let memberSince: String   // ISO YYYY-MM-DD
    let totalWeeksTrained: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}

// MARK: - Subscription

struct SubscriptionStatus: Sendable {
    enum Tier: Sendable, Hashable {
        case free, plus, premium

        var displayLabel: String {
            switch self {
            case .free:    return "Free"
            case .plus:    return "BYOW+"
            case .premium: return "BYOW Pro"
            }
        }
    }

    let tier: Tier
    let planLabel: String        // e.g. "BYOW+ Annual"
    let priceLabel: String?      // e.g. "$99 / year"
    let renewsOn: String?        // ISO
    let trialDaysLeft: Int?
    let isActive: Bool
    let perks: [String]
    let storeManageURL: URL?
}

// MARK: - Body profile

struct BodyProfile: Sendable {
    enum Sex: String, Sendable, CaseIterable, Hashable {
        case male, female, other, undisclosed

        var displayLabel: String {
            switch self {
            case .male:        return "Male"
            case .female:      return "Female"
            case .other:       return "Other"
            case .undisclosed: return "Prefer not to say"
            }
        }
    }

    enum Goal: String, Sendable, CaseIterable, Hashable {
        case lose, maintain, gain, recomp

        var displayLabel: String {
            switch self {
            case .lose:     return "Lose fat"
            case .maintain: return "Maintain"
            case .gain:     return "Gain mass"
            case .recomp:   return "Recomp"
            }
        }
    }

    var dateOfBirth: String      // ISO YYYY-MM-DD
    var heightInches: Int        // 70 = 5'10"
    var weightLb: Double?        // synced from Apple Health
    var sex: Sex
    var goal: Goal

    /// "5'10""
    var heightLabel: String {
        let ft = heightInches / 12
        let inch = heightInches % 12
        return "\(ft)′ \(inch)″"
    }

    var ageYears: Int? {
        guard let dob = ISODate.parse(dateOfBirth) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
}

// MARK: - Account & security

struct AccountInfo: Sendable, Hashable {
    var email: String
    var hasBiometricLogin: Bool
    var lastPasswordChangeDays: Int?   // nil = never
    var activeSessions: Int
}

// MARK: - Coach assignment

struct CoachAssignment: Sendable {
    enum AIPersonality: String, Sendable, CaseIterable, Hashable {
        case direct, encouraging, technical

        var displayLabel: String {
            switch self {
            case .direct:       return "Direct"
            case .encouraging:  return "Encouraging"
            case .technical:    return "Technical"
            }
        }

        var detail: String {
            switch self {
            case .direct:      return "Cuts to the takeaway. No fluff."
            case .encouraging: return "Celebrates wins, frames misses gently."
            case .technical:   return "Detail-rich — cites bar speed, RPE, and load."
            }
        }
    }

    let firstName: String
    let role: String
    let avatarSymbol: String
    let lastCheckInDays: Int
    var aiPersonality: AIPersonality
}

// MARK: - Notifications

struct NotificationPrefs: Sendable, Hashable {
    var workoutReminders: Bool
    var weeklyInsights: Bool
    var prCelebrations: Bool
    var coachMessages: Bool
    var bridgeWeekHeadsUp: Bool
}

// MARK: - Privacy

struct PrivacyPrefs: Sendable, Hashable {
    var shareWithCoach: Bool
    var shareWithHealth: Bool
}

// MARK: - App info

struct AppInfo: Sendable, Hashable {
    let version: String
    let buildNumber: String
    let environment: String   // e.g. "Phase 1 · Mock"
}
