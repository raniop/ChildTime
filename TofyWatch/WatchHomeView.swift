import SwiftUI
import WatchConnectivity

/// One child's glance row, as sent from the iPhone (see WatchBridge.swift).
struct WatchChildGlance: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let earnedToday: Int
    let playingNow: Bool
    let pendingChores: Int
    let moneyBalance: Int
}

/// Receives the family snapshot the iPhone pushes via applicationContext.
final class WatchFamilyModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var children: [WatchChildGlance] = []
    @Published var updatedAt: Date?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ ctx: [String: Any]) {
        guard let rows = ctx["children"] as? [[String: Any]] else { return }
        let parsed = rows.map { r in
            WatchChildGlance(id: r["id"] as? String ?? UUID().uuidString,
                             name: r["name"] as? String ?? "?",
                             emoji: r["emoji"] as? String ?? "🦊",
                             earnedToday: r["earnedToday"] as? Int ?? 0,
                             playingNow: r["playingNow"] as? Bool ?? false,
                             pendingChores: r["pendingChores"] as? Int ?? 0,
                             moneyBalance: r["moneyBalance"] as? Int ?? 0)
        }
        let stamp = (ctx["sentAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        DispatchQueue.main.async {
            self.children = parsed
            self.updatedAt = stamp
        }
    }
}

/// ⌚️ The parent's glance: one card per child — playing-now, today's earned
/// minutes, chores waiting for approval, and the 💰 pocket.
struct WatchHomeView: View {
    @StateObject private var model = WatchFamilyModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.children.isEmpty {
                    VStack(spacing: 8) {
                        Text("🦁").font(.system(size: 40))
                        Text("טופי")
                            .font(.headline)
                        Text("פתחו את טופי באייפון פעם אחת — והמשפחה תופיע כאן")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(model.children) { child in
                            childRow(child)
                        }
                        if let t = model.updatedAt {
                            Text("עודכן \(t.formatted(date: .omitted, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("טופי 🦁")
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func childRow(_ child: WatchChildGlance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(child.emoji) \(child.name)")
                    .font(.headline)
                Spacer()
                if child.playingNow {
                    Circle().fill(.green).frame(width: 8, height: 8)
                }
            }
            HStack(spacing: 8) {
                Text("🎮 \(child.earnedToday) דק׳")
                if child.moneyBalance > 0 { Text("💰 ₪\(child.moneyBalance)") }
                if child.pendingChores > 0 { Text("🧹 \(child.pendingChores) 🕐") }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
