import Foundation

/// Turns a friend code into a shareable link (and back). The QR encodes the
/// https link, so it can be scanned by the native Camera too. We ALSO support a
/// custom `tofy://friend?f=CODE` scheme so the web landing page can bounce
/// straight into the app even before Apple's AASA cache catches up.
enum FriendLink {
    static let host = JoinLink.host          // tofyapp.com
    static let scheme = "tofy"               // custom URL scheme

    /// The https Universal Link for a friend code (what the QR / share uses).
    static func url(forCode code: String) -> String {
        var c = URLComponents()
        c.scheme = "https"; c.host = host; c.path = "/friend"
        c.queryItems = [URLQueryItem(name: "f", value: code)]
        return c.url?.absoluteString ?? code
    }

    /// The custom-scheme deep link (used by the web page's auto-bounce).
    static func appURL(forCode code: String) -> String {
        "\(scheme)://friend?f=\(code)"
    }

    /// Pull the bare friend code out of anything — a bare code, an https link, or
    /// a `tofy://` deep link.
    static func code(from scanned: String) -> String {
        let s = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comps = URLComponents(string: s),
           comps.scheme != nil,
           let f = comps.queryItems?.first(where: { $0.name == "f" })?.value, !f.isEmpty {
            return f
        }
        return s   // already a bare code
    }

    /// Is this an incoming friend link (Universal Link OR custom scheme)?
    static func isFriendURL(_ url: URL) -> Bool {
        if url.scheme == scheme, url.host == "friend" { return true }
        return (url.host == host || url.host == "www.\(host)") && url.path.hasPrefix("/friend")
    }
}
