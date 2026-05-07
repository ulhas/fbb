import Foundation
import Observation
import FBBWorkoutKitCore
import FBBWorkoutKitNet

/// Watch-side Today loader. Loads the current week and pulls today's day
/// detail; surfaces all followed tracks' day cells so the user can pick.
@Observable
@MainActor
final class WatchHomeViewModel {
    enum LoadState: Sendable {
        case idle
        case loading
        case loaded(today: [TrainingWeekDayCellRow])
        case empty
        case failed(String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    private let api: APIClient
    var state: LoadState = .idle

    init(api: APIClient) {
        self.api = api
    }

    func load(force: Bool = false) async {
        state = .loading
        do {
            let weeks = try await api.listWeeks(forceRefresh: force)
            let today = ISO8601.todayString()
            // Find the week that contains today (its weekStartsOn ≤ today ≤ weekEndsOn).
            guard let week = weeks.first(where: { $0.weekStartsOn <= today && today <= $0.weekEndsOn }) else {
                state = .empty
                return
            }
            let detail = try await api.day(
                weekStartsOn: week.weekStartsOn,
                scheduledOn: today,
                forceRefresh: force
            )
            if detail.cells.isEmpty {
                state = .empty
            } else {
                state = .loaded(today: detail.cells)
            }
        } catch let apiError as APIError {
            if case .notFound = apiError {
                state = .empty
            } else {
                state = .failed(apiError.errorDescription ?? "Couldn't load today.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// Tiny ISO-date helper used by both the home VM and the watch session
/// store. Mirrors the iOS `ISODate` helper without depending on it.
enum ISO8601 {
    static func todayString(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }
}
