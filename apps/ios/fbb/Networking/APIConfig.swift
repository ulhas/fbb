import Foundation

enum APIConfig {
    static let baseURL: URL = {
        #if DEBUG
        // Simulator localhost; on a physical device override via Info.plist later.
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "https://api.persist.functionalbodybuilding.com")!
        #endif
    }()

    /// Stub for now; wired in when auth lands. Bearer token from Supabase / RC JWT.
    static var bearerToken: String? { nil }
}
