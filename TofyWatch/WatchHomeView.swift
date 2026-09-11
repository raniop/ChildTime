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
        // WATCH_DEMO=1 — sample family for design review and screenshots. Never
        // set in a shipping run; the watch has no other way to show a full
        // screen without a paired phone pushing real data.
        if ProcessInfo.processInfo.environment["WATCH_DEMO"] == "1" {
            children = [
                .init(id: "1", name: tr("דָּנָה"), emoji: "🦊", earnedToday: 35,
                      playingNow: true, pendingChores: 1, moneyBalance: 24),
                .init(id: "2", name: tr("יוֹאָב"), emoji: "🐨", earnedToday: 10,
                      playingNow: false, pendingChores: 0, moneyBalance: 0),
                .init(id: "3", name: tr("אוּרִי"), emoji: "🐻", earnedToday: 0,
                      playingNow: false, pendingChores: 2, moneyBalance: 7),
            ]
            updatedAt = Date()
            return
        }
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
        if let code = ctx["language"] as? String, let lang = AppLanguage(rawValue: code) {
            DispatchQueue.main.async { LanguageStore.shared.set(lang) }
        }
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

/// ⌚️ Tofy on the wrist.
///
/// The old screen was a stock `List` of grey rows — everything the phone app is
/// not. A watch glance is read in about a second, so this trades the list for
/// pages the Digital Crown flicks through: the family first, then one page per
/// child, each one big enough to read without looking twice.
struct WatchHomeView: View {
    @StateObject private var model = WatchFamilyModel()
    @ObservedObject private var language = LanguageStore.shared

    var body: some View {
        ZStack {
            WatchBackdrop()
            if model.children.isEmpty {
                emptyState
            } else {
                TabView {
                    familyPage
                    ForEach(model.children) { child in
                        childPage(child)
                    }
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .environment(\.layoutDirection, language.current.layoutDirection)
        .id(language.current)
    }

    // MARK: - Family

    private var playing: [WatchChildGlance] { model.children.filter(\.playingNow) }
    private var minutesToday: Int { model.children.reduce(0) { $0 + $1.earnedToday } }
    private var choresWaiting: Int { model.children.reduce(0) { $0 + $1.pendingChores } }

    private var familyPage: some View {
        VStack(spacing: 8) {
            Text(tr("🦁 טוֹפִי"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(headline)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                stat("\(minutesToday)", tr("דַּקּוֹת הַיּוֹם"), tint: Tofy.mint)
                if choresWaiting > 0 {
                    stat("\(choresWaiting)", tr("מַטָּלוֹת"), tint: Tofy.gold)
                }
            }

            if let t = model.updatedAt {
                Text(tr("עֻדְכַּן \(t.formatted(date: .omitted, time: .shortened))"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 6)
    }

    private var headline: String {
        if let one = playing.first {
            return playing.count == 1
                ? tr("\(one.name) מְשַׂחֵק עַכְשָׁו")
                : tr("\(playing.count) יְלָדִים מְשַׂחֲקִים עַכְשָׁו")
        }
        switch model.children.count {
        case 1: return tr("יֶלֶד אֶחָד · אַף אֶחָד לֹא מְשַׂחֵק")
        case 2: return tr("שְׁנֵי יְלָדִים · שֶׁקֶט עַכְשָׁו")
        default: return tr("\(model.children.count) יְלָדִים · שֶׁקֶט עַכְשָׁו")
        }
    }

    private func stat(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .watchPane(radius: 12)
    }

    // MARK: - One child

    private func childPage(_ c: WatchChildGlance) -> some View {
        VStack(spacing: 7) {
            Text(c.emoji).font(.system(size: 34))

            HStack(spacing: 5) {
                if c.playingNow {
                    Circle().fill(Tofy.mint).frame(width: 7, height: 7)
                }
                Text(c.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }

            Text(c.playingNow ? tr("מְשַׂחֵק עַכְשָׁו") : tr("לֹא מְשַׂחֵק כָּרֶגַע"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(c.playingNow ? Tofy.mint : .white.opacity(0.65))

            VStack(spacing: 4) {
                row("🎮", tr("\(c.earnedToday) דַּקּוֹת הַיּוֹם"))
                if c.pendingChores > 0 {
                    row("🧹", c.pendingChores == 1 ? tr("מַטָּלָה מְחַכָּה לְאִשּׁוּר")
                                                   : tr("\(c.pendingChores) מַטָּלוֹת מְחַכּוֹת"))
                }
                if c.moneyBalance > 0 {
                    row("💰", tr("\(Money.pocket(c.moneyBalance)) בַּקֻּפָּה"))
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 9)
            .watchPane(radius: 13, tint: c.playingNow ? Tofy.mint : nil)
        }
        .padding(.horizontal, 6)
    }

    private func row(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 13))
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Nothing yet

    private var emptyState: some View {
        VStack(spacing: 7) {
            Text("🦁").font(.system(size: 38))
            Text(tr("טוֹפִי"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("פִּתְחוּ אֶת טוֹפִי בָּאַיְפוֹן פַּעַם אַחַת — וְהַמִּשְׁפָּחָה תּוֹפִיעַ כָּאן"))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
    }
}
