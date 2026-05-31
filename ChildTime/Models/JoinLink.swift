import Foundation

/// Turns a child-join payload ("CODE|childID") into a shareable Universal Link
/// and back. The QR encodes the link so it can be scanned by the iPhone's native
/// Camera app (not just inside Tofy) — iOS opens the app straight to joining.
enum JoinLink {
    static let host = "tofyapp.com"

    /// Build the https Universal Link the QR will encode.
    static func url(forPayload payload: String) -> String {
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        let code = (parts.first ?? payload).trimmingCharacters(in: .whitespacesAndNewlines)
        let child = parts.count > 1 ? parts[1] : ""
        var c = URLComponents()
        c.scheme = "https"; c.host = host; c.path = "/join"
        var items = [URLQueryItem(name: "c", value: code)]
        if !child.isEmpty { items.append(URLQueryItem(name: "k", value: child)) }
        c.queryItems = items
        return c.url?.absoluteString ?? payload
    }

    /// Normalize anything a scanner/Camera produces — a raw "CODE|childID" OR a
    /// join link — into the internal "CODE|childID" payload.
    static func payload(from scanned: String) -> String {
        let s = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("http"),
              let comps = URLComponents(string: s),
              comps.path.hasPrefix("/join")
        else { return s }   // already a bare payload
        let code = comps.queryItems?.first(where: { $0.name == "c" })?.value ?? ""
        let child = comps.queryItems?.first(where: { $0.name == "k" })?.value ?? ""
        guard !code.isEmpty else { return s }
        return child.isEmpty ? code : "\(code)|\(child)"
    }

    /// Is this an incoming join Universal Link?
    static func isJoinURL(_ url: URL) -> Bool {
        (url.host == host || url.host == "www.\(host)") && url.path.hasPrefix("/join")
    }
}
