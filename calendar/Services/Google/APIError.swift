import Foundation

extension Error {
    var isPermissionDenied: Bool {
        guard let apiError = self as? APIError else { return false }
        return apiError.isPermissionDenied
    }
}

/// Errors returned by Google API requests.
nonisolated enum APIError: LocalizedError, Sendable, Equatable {
    nonisolated static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.rateLimited, .rateLimited): true
        case (.httpError(let a, _), .httpError(let b, _)): a == b
        default: false
        }
    }

    /// A non-2xx HTTP response was received.
    case httpError(statusCode: Int, body: String)
    /// The API returned HTTP 429 (Too Many Requests).
    case rateLimited

    var isPermissionDenied: Bool {
        switch self {
        case .httpError(let code, _): code == 401 || code == 403
        case .rateLimited: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        case .rateLimited: "Rate limited by Google API. Will retry later."
        }
    }
}
