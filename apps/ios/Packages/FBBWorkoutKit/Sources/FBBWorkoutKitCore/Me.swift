import Foundation

/// Server reflection of who I am. Returned by `GET /me`. The follow set
/// lives here (not in a separate /me/follows endpoint) so the bootstrap
/// roundtrip carries everything Today needs to render its track filter.
public struct Me: Codable, Sendable, Hashable {
    public let id: String
    public let email: String?
    public let displayName: String?
    public let followedTrackCodes: [String]
}

/// One row from `GET /me/tracks` — the catalog of active tracks plus a
/// per-row `isFollowed` so the picker can render check-state without a
/// second query against `Me.followedTrackCodes`.
public struct TrackCatalogRow: Codable, Sendable, Hashable, Identifiable {
    public var id: String { code }
    public let code: String
    public let family: String
    public let cadence: String?
    public let displayName: String
    public let shortName: String?
    public let description: String?
    public let requiredEquipment: [String]
    public let sortOrder: Int
    public let isFollowed: Bool
}
