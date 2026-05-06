import Foundation

enum APIError: Error, LocalizedError, Sendable {
    case transport(URLError)
    case http(status: Int, body: String?)
    case decoding(String)
    case notFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .transport(let err):
            return err.localizedDescription
        case .http(let status, _):
            return "Server returned \(status)."
        case .decoding(let msg):
            return "Couldn't read server response. (\(msg))"
        case .notFound:
            return "No content for that week."
        case .unknown(let msg):
            return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .transport: return true
        case .http(let status, _): return status >= 500
        case .unknown: return true
        case .decoding, .notFound: return false
        }
    }
}
