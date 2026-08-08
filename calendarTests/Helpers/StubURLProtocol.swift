import Foundation

@testable import calendar

/// Serves canned HTTP responses to a `URLSession`, so the real
/// ``GoogleCalendarAPI`` — including its retry loop and error classification —
/// can be exercised without a network.
///
/// Responses are consumed in order; the last one repeats once the queue drains,
/// which keeps "fails forever" scripts short.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    struct Response: Sendable {
        let statusCode: Int
        let body: Data
        let headers: [String: String]

        init(statusCode: Int, body: Data = Data(), headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.body = body
            self.headers = headers
        }

        static func json(_ statusCode: Int, _ json: String, headers: [String: String] = [:])
            -> Response
        {
            Response(statusCode: statusCode, body: Data(json.utf8), headers: headers)
        }
    }

    // URLProtocol is instantiated by the loading system, so the script has to
    // live somewhere both the test and the instances can reach.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var queue: [Response] = []
    nonisolated(unsafe) private static var recordedURLs: [URL] = []

    /// Installs `responses` and clears any previous recording.
    static func script(_ responses: [Response]) {
        lock.withLock {
            queue = responses
            recordedURLs = []
        }
    }

    /// Every URL requested since the last ``script(_:)``, in order.
    static var requestedURLs: [URL] {
        lock.withLock { recordedURLs }
    }

    /// Number of requests served since the last ``script(_:)``.
    static var requestCount: Int {
        lock.withLock { recordedURLs.count }
    }

    /// A session wired to this stub. Retries are made instant so a test does
    /// not sleep through real backoff.
    static func makeAPI(maxAttempts: Int = 4) -> GoogleCalendarAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return GoogleCalendarAPI(
            session: URLSession(configuration: config),
            retryPolicy: RetryPolicy(maxAttempts: maxAttempts) { _, _ in 0 }
        )
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let next: Response = Self.lock.withLock {
            if let url = request.url { Self.recordedURLs.append(url) }
            guard !Self.queue.isEmpty else {
                return Response(statusCode: 500, body: Data("{}".utf8))
            }
            // Keep the final response in place so "always fails" needs one entry.
            return Self.queue.count == 1 ? Self.queue[0] : Self.queue.removeFirst()
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: next.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: next.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
