import Foundation

/// Turns a friend code into a shareable Universal Link (and back). The QR encodes
/// the same link, so it can be scanned by the native Camera too — iOS opens Tofy
/// straight to "add this friend".
enum FriendLink {
    static let host = JoinLink.host   // tofyapp.com

    /// The https Universal Link for a friend code.
    static func url(forCode code: String) -> String {
        var c = URLComponents()
        c.scheme = "https"; c.host = host; c.path = "/friend"
        c.queryItems = [URLQueryItem(name: "f", value: code)]
        return c.url?.absoluteString ?? code
    }

    /// Normalize anything a scanner/Camera produces — a raw code OR a friend
    /// link — into the bare friend code.
    static func code(from scanned: String) -> String {
        let s = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("http"),
              let comps = URLComponents(string: s),
              comps.path.hasPrefix("/friend")
        else { return s }   // already a bare code
        return comps.queryItems?.first(where: { $0.name == "f" })?.value ?? s
    }

    static func isFriendURL(_ url: URL) -> Bool {
        (url.host == host || url.host == "www.\(host)") && url.path.hasPrefix("/friend")
    }
}
