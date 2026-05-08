import Foundation

protocol ProfileSource: Sendable {
    func loadProfile(forceRefresh: Bool) async throws -> ProfileData
}

// MARK: - Mock implementation

struct MockProfileSource: ProfileSource {
    let now: Date
    init(now: Date = Date()) { self.now = now }

    func loadProfile(forceRefresh: Bool) async throws -> ProfileData {
        try? await Task.sleep(for: .milliseconds(forceRefresh ? 280 : 140))
        return ProfileMockData.build(now: now)
    }
}

// MARK: - Mock data

enum ProfileMockData {

    static func build(now: Date) -> ProfileData {
        ProfileData(
            user: user(now: now),
            subscription: subscription(now: now),
            body: body,
            account: account,
            coach: coach,
            notifications: notifications,
            privacy: privacy,
            appInfo: appInfo
        )
    }

    static func user(now: Date) -> UserHeader {
        let cal = Calendar.iso8601UTCFromProfile
        // Member since ~ 23 weeks ago
        let memberSince = cal.date(byAdding: .day, value: -23 * 7, to: now) ?? now
        return UserHeader(
            firstName: "Alex",
            lastName: "Cole",
            email: "alex@byow.training",
            memberSince: ISODate.string(memberSince),
            totalWeeksTrained: 23
        )
    }

    static func subscription(now: Date) -> SubscriptionStatus {
        let cal = Calendar.iso8601UTCFromProfile
        let renews = cal.date(byAdding: .day, value: 232, to: now) ?? now
        return SubscriptionStatus(
            tier: .plus,
            planLabel: "BYOW+ Annual",
            priceLabel: "$99 / year",
            renewsOn: ISODate.string(renews),
            trialDaysLeft: nil,
            isActive: true,
            perks: [
                "All training tracks",
                "AI Coach reads & insights",
                "Coach review of your week",
                "Apple Health sync",
                "Photo nutrition logging (Phase 4)"
            ],
            storeManageURL: URL(string: "https://apps.apple.com/account/subscriptions")
        )
    }

    static let body = BodyProfile(
        dateOfBirth: "1992-04-18",
        heightInches: 70,
        weightLb: 180.4,           // mirrors Stats Recovery latest weight
        sex: .male,
        goal: .recomp
    )

    static let account = AccountInfo(
        email: "alex@byow.training",
        hasBiometricLogin: true,
        lastPasswordChangeDays: 12,
        activeSessions: 2
    )

    static let coach = CoachAssignment(
        firstName: "Sarah",
        role: "Head Coach",
        avatarSymbol: "person.crop.circle.fill",
        lastCheckInDays: 3,
        aiPersonality: .encouraging
    )

    static let notifications = NotificationPrefs(
        workoutReminders: true,
        weeklyInsights: true,
        prCelebrations: true,
        coachMessages: true,
        bridgeWeekHeadsUp: true
    )

    static let privacy = PrivacyPrefs(
        shareWithCoach: true,
        shareWithHealth: true
    )

    static let appInfo = AppInfo(
        version: "0.1.0",
        buildNumber: "12",
        environment: "Phase 1 · Mock"
    )
}

// MARK: - Calendar helper

private extension Calendar {
    static var iso8601UTCFromProfile: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }
}
