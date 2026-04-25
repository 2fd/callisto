import Foundation

extension GoogleCalendarEvent {
  /// Returns the conference link URL, if present.
  var conferenceMeetURL: URL? {
    conferenceLink.flatMap(URL.init(string:))
  }

  /// Conference link stamped with `authuser=N`, overwriting any existing value.
  func conferenceMeetURL(authuser: Int) -> URL? {
    conferenceMeetURL.map { $0.settingAuthUser(authuser) }
  }

  /// Calendar `htmlLink` stamped with `authuser=N`, overwriting any existing value.
  func calendarURL(authuser: Int) -> URL? {
    URL(string: htmlLink).map { $0.settingAuthUser(authuser) }
  }
}

extension URL {
  /// Returns a copy of this URL with its `authuser` query parameter set to
  /// `value`, replacing any existing `authuser` item.
  func settingAuthUser(_ value: Int) -> URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      return self
    }
    var items = (components.queryItems ?? []).filter { $0.name != "authuser" }
    items.append(URLQueryItem(name: "authuser", value: String(value)))
    components.queryItems = items
    return components.url ?? self
  }
}
