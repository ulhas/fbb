import Foundation

protocol DateProvider: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProvider {
    var now: Date { Date() }
}

/// Test fixture: locks `now` to a predetermined value.
struct FixedDateProvider: DateProvider {
    let now: Date
    init(_ now: Date) { self.now = now }
}
