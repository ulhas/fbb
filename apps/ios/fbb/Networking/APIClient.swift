import Foundation

/// Read-side HTTP client for the training-weeks API.
///
/// In-memory caching only (Phase 1). Disk persistence (PowerSync / SwiftData)
/// is Phase 2.
actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    private var weekList: [TrainingWeekSummaryRow]?
    private var weekIndex: [String: TrainingWeekDetailRow] = [:]
    private var dayDetail: [String: TrainingWeekDayDetailRow] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - Public reads (stale-while-revalidate via `forceRefresh`)

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

    /// Drops every cached value. Pull-to-refresh delegates to per-key
    /// `forceRefresh: true` instead, but this is here for logout / account switch.
    func clearCache() {
        weekList = nil
        weekIndex.removeAll()
        dayDetail.removeAll()
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
}
