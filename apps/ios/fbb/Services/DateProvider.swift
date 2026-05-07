import Foundation

protocol DateProvider: Sendable {
    var now: Date { get }
}

/// Explicitly `nonisolated` so it can be used as a default parameter
/// expression on `@MainActor`-isolated initializers without tripping
/// Swift 6's strict concurrency checks. Default parameter expressions
/// evaluate in a nonisolated context, but Swift 6 was inferring this
/// type's synthesized init as MainActor-isolated by default.
struct SystemDateProvider: DateProvider {
    nonisolated init() {}
    nonisolated var now: Date { Date() }
}

/// Test fixture: locks `now` to a predetermined value.
struct FixedDateProvider: DateProvider {
    let now: Date
    nonisolated init(_ now: Date) { self.now = now }
}
