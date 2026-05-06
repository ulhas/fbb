import Foundation

/// Read-side HTTP client for the API.
///
/// In-memory caching only (Phase 1). Disk persistence (PowerSync / SwiftData)
/// is Phase 2.
actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    private var weekList: [TrainingWeekSummaryRow]?
    private var weekIndex: [String: TrainingWeekDetailRow] = [:]
    private var dayDetail: [String: TrainingWeekDayDetailRow] = [:]
    private var meCache: Me?
    private var trackCatalogCache: [TrackCatalogRow]?

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - Training-week reads (stale-while-revalidate via `forceRefresh`)

    func listWeeks(forceRefresh: Bool = false) async throws -> [TrainingWeekSummaryRow] {
        if !forceRefresh, let cached = weekList { return cached }
        let value: [TrainingWeekSummaryRow] = try await get(.listWeeks)
        weekList = value
        return value
    }

    func week(_ weekStartsOn: String, forceRefresh: Bool = false) async throws -> TrainingWeekDetailRow {
        if !forceRefresh, let cached = weekIndex[weekStartsOn] { return cached }
        let value: TrainingWeekDetailRow = try await get(.weekDetail(weekStartsOn: weekStartsOn))
        weekIndex[weekStartsOn] = value
        return value
    }

    func day(weekStartsOn: String, scheduledOn: String, forceRefresh: Bool = false) async throws -> TrainingWeekDayDetailRow {
        let key = "\(weekStartsOn)#\(scheduledOn)"
        if !forceRefresh, let cached = dayDetail[key] { return cached }
        let value: TrainingWeekDayDetailRow =
            try await get(.dayDetail(weekStartsOn: weekStartsOn, scheduledOn: scheduledOn))
        dayDetail[key] = value
        return value
    }

    // MARK: - User reads

    func me(forceRefresh: Bool = false) async throws -> Me {
        if !forceRefresh, let cached = meCache { return cached }
        let value: Me = try await get(.me)
        meCache = value
        return value
    }

    func tracksCatalog(forceRefresh: Bool = false) async throws -> [TrackCatalogRow] {
        if !forceRefresh, let cached = trackCatalogCache { return cached }
        let value: [TrackCatalogRow] = try await get(.meTracks)
        trackCatalogCache = value
        return value
    }

    // MARK: - User writes

    func followTrack(_ code: String) async throws {
        try await voidRequest(.followTrack(code: code), method: "POST")
        invalidateUserCache()
    }

    func unfollowTrack(_ code: String) async throws {
        try await voidRequest(.unfollowTrack(code: code), method: "DELETE")
        invalidateUserCache()
    }

    /// Drops every cached value. Pull-to-refresh delegates to per-key
    /// `forceRefresh: true` instead, but this is here for logout / account switch.
    func clearCache() {
        weekList = nil
        weekIndex.removeAll()
        dayDetail.removeAll()
        invalidateUserCache()
    }

    private func invalidateUserCache() {
        meCache = nil
        trackCatalogCache = nil
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, http) = try await perform(endpoint, method: "GET")
        if http.statusCode == 404 { throw APIError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding("\(error)")
        }
    }

    private func voidRequest(_ endpoint: Endpoint, method: String) async throws {
        let (data, http) = try await perform(endpoint, method: method)
        if http.statusCode == 404 { throw APIError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    private func perform(_ endpoint: Endpoint, method: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APIConfig.deviceUserId, forHTTPHeaderField: "X-User-Id")
        if let token = APIConfig.bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(error)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("Bad server response.")
        }
        return (data, http)
    }
}
