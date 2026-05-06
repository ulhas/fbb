import Foundation

/// Server reflection of who I am. Returned by `GET /me`. The follow set
/// lives here (not in a separate /me/follows endpoint) so the bootstrap
/// roundtrip carries everything Today needs to render its track filter.
struct Me: Codable, Sendable, Hashable {
    let id: String
    let email: String?
    let displayName: String?
    let followedTrackCodes: [String]
}

/// One row from `GET /me/tracks` — the catalog of active tracks plus a
/// per-row `isFollowed` so the picker can render check-state without a
/// second query against `Me.followedTrackCodes`.
struct TrackCatalogRow: Codable, Sendable, Hashable, Identifiable {
    var id: String { code }
    let code: String
    let family: String
    let cadence: String?
    let displayName: String
    let shortName: String?
    let description: String?
    let requiredEquipment: [String]
    let sortOrder: Int
    let isFollowed: Bool
}
