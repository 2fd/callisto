import Foundation

extension URL {
  /// The Zoom client deep link for a `https://…zoom.us/j/<id>` join link, or
  /// `nil` when this is not one.
  ///
  /// Mirrors what Zoom's own launch page opens on macOS:
  /// `zoomus://<host>/join?action=join&confno=<id>&pwd=<pwd>`. The host is
  /// kept as is (`us06web.zoom.us`, vanity subdomains); every other query
  /// item (`authuser`, `jst`, …) is dropped. Personal links (`/my/<name>`)
  /// carry no meeting number, so they stay in the browser.
  var zoomAppURL: URL? {
    guard scheme == "https" || scheme == "http",
      let host = host?.lowercased(),
      host == "zoom.us" || host.hasSuffix(".zoom.us")
    else { return nil }

    let segments = pathComponents.filter { $0 != "/" }
    guard segments.count == 2, segments[0] == "j",
      !segments[1].isEmpty, segments[1].allSatisfy(\.isASCII), segments[1].allSatisfy(\.isNumber)
    else { return nil }

    var components = URLComponents()
    components.scheme = "zoomus"
    components.host = host
    components.path = "/join"
    var items = [
      URLQueryItem(name: "action", value: "join"),
      URLQueryItem(name: "confno", value: segments[1]),
    ]
    let query = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
    if let pwd = query.first(where: { $0.name == "pwd" })?.value, !pwd.isEmpty {
      items.append(URLQueryItem(name: "pwd", value: pwd))
    }
    components.queryItems = items
    return components.url
  }
}
