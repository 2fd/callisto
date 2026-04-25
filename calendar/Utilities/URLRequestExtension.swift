import Foundation

extension URLRequest {
    /// Creates a POST request with a `application/x-www-form-urlencoded` body.
    ///
    /// Encodes the parameters using percent-encoding and sets the `Content-Type`
    /// header automatically. This is the encoding required by OAuth 2.0 token
    /// endpoints (RFC 6749 Section 4.1.3).
    ///
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - parameters: Key-value pairs to encode as the form body.
    init(formPost url: URL, parameters: [String: String]) {
        self.init(url: url)
        httpMethod = "POST"
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+=&")
        httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}
