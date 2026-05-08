import Foundation

public enum APIConfig {
    public static let baseURL: URL = {
        #if DEBUG
        // Simulator localhost; on a physical device override via Info.plist later.
        return URL(string: "http://localhost:3000/api/v1")!
        #else
        return URL(string: "https://api.persist.functionalbodybuilding.com/api/v1")!
        #endif
    }()

    /// App Group used to share auth identity (and eventually pending-sync
    /// blobs) between the iOS app and the watch app. Both targets must
    /// declare this group in their entitlements file.
    public static let appGroupIdentifier = "group.ai.byow.ios"

    /// Shared UserDefaults suite. Falls back to `.standard` if the App
    /// Group entitlement is missing for some reason — surfaces as the
    /// pre-App-Group behaviour (per-target identity) rather than crashing.
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// Stub for now; wired in when auth lands. Bearer token from Supabase / RC JWT.
    public static var bearerToken: String? { nil }

    /// Phase-1 device-bound identity. A UUID minted on first launch and
    /// echoed in `X-User-Id` so the API can resolve a stable user row before
    /// real auth ships.
    ///
    /// Stored in the shared App Group suite so iOS and watch read the same
    /// value — that's what lets the watch see the iOS user's followed
    /// tracks. On first run after upgrade, copies any pre-existing legacy
    /// UUID from `UserDefaults.standard` so existing users keep their
    /// identity (and their server-side data).
    public static var deviceUserId: String {
        let key = "byow.deviceUserId.v1"
        let shared = sharedDefaults

        if let stored = shared.string(forKey: key), !stored.isEmpty {
            return stored
        }

        // One-time migration from per-target .standard UUID, if one exists.
        if let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
            shared.set(legacy, forKey: key)
            return legacy
        }

        let fresh = UUID().uuidString.lowercased()
        shared.set(fresh, forKey: key)
        return fresh
    }
}
