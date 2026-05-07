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

    /// Stub for now; wired in when auth lands. Bearer token from Supabase / RC JWT.
    public static var bearerToken: String? { nil }

    /// Phase-1 device-bound identity. A UUID minted on first launch and
    /// echoed in `X-User-Id` so the API can resolve a stable user row before
    /// real auth ships. Persisted in UserDefaults; Keychain is the right
    /// long-term home (survives reinstall).
    public static var deviceUserId: String {
        let key = "fbb.deviceUserId.v1"
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let fresh = UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
