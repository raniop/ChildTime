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
    var girl: Bool = false
    var hasDevice: Bool = false
    /// "🏠 בבית · לפני 3 דק׳" — empty when location sharing is off.
    var whereText: String = ""
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
                .init(id: "1", name: tr("דנה"), emoji: "🦊", earnedToday: 35,
                      playingNow: true, pendingChores: 1, moneyBalance: 24,
                      girl: true, hasDevice: true, whereText: "🏫 בבית הספר · לפני 4 דק׳"),
                .init(id: "2", name: tr("יואב"), emoji: "🐨", earnedToday: 10,
                      playingNow: false, pendingChores: 0, moneyBalance: 0,
                      girl: false, hasDevice: true, whereText: "🏠 בבית · עכשיו"),
                .init(id: "3", name: tr("אורי"), emoji: "🐻", earnedToday: 0,
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

    /// "נשלח ✓" / "יישלח כשהאייפון יתחבר" after an action.
    @Published var note: String?

    /// ⚡ Ask the phone to do it (gift / lock / beep). Live when the phone is in
    /// reach; otherwise queued, and it runs when they reconnect.
    func send(_ action: String, childID: String, minutes: Int = 0) {
        var msg: [String: Any] = ["action": action, "childID": childID]
        if minutes > 0 { msg["minutes"] = minutes }
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { show(tr("האייפון לא זמין כרגע")); return }
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { r in
                let ok = r["ok"] as? Bool ?? false
                if ok, let m = r["minutes"] as? Int, m < minutes {
                    self.show(tr("נשלח ✓ · \(m) דק׳ — עד חצות"))
                } else {
                    self.show(ok ? tr("נשלח ✓") : tr("לא הצליח — נסו מהאייפון"))
                }
            }, errorHandler: { _ in
                session.transferUserInfo(msg)
                self.show(tr("יישלח כשהאייפון יתחבר"))
            })
        } else {
            session.transferUserInfo(msg)
            show(tr("יישלח כשהאייפון יתחבר"))
        }
    }

    private func show(_ text: String) {
        DispatchQueue.main.async {
            self.note = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { if self.note == text { self.note = nil } }
        }
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
                             moneyBalance: r["moneyBalance"] as? Int ?? 0,
                             girl: r["girl"] as? Bool ?? false,
                             hasDevice: r["hasDevice"] as? Bool ?? false,
                             whereText: r["where"] as? String ?? "")
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
    /// -1 = the family page. WATCH_DEMO_PAGE=0… opens a child's page (screenshots).
    @State private var page: Int = ProcessInfo.processInfo.environment["WATCH_DEMO_PAGE"].flatMap(Int.init) ?? -1

    var body: some View {
        ZStack {
            WatchBackdrop()
            if model.children.isEmpty {
                emptyState
            } else if ProcessInfo.processInfo.environment["WATCH_DEMO_ACTIONS"] == "1" {
                // WATCH_DEMO_ACTIONS=1 — the actions page on its own (screenshots).
                NavigationStack {
                    actionsPage(model.children[min(max(page, 0), model.children.count - 1)])
                }
            } else {
                NavigationStack {
                TabView(selection: $page) {
                    familyPage.tag(-1)
                    ForEach(Array(model.children.enumerated()), id: \.element.id) { i, child in
                        childPage(child).tag(i)
                    }
                }
                .tabViewStyle(.verticalPage)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let note = model.note {
                Text(note)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(tofyHex: "2A1E5C"))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .padding(.bottom, 4)
            }
        }
        .environment(\.layoutDirection, language.current.layoutDirection)
        .id(language.current)
    }

    // MARK: - Family
    // Parent side → no niqqud (Rani: "כל המסכים בצד הורה בלי ניקוד").

    private var playing: [WatchChildGlance] { model.children.filter(\.playingNow) }
    private var minutesToday: Int { model.children.reduce(0) { $0 + $1.earnedToday } }
    private var choresWaiting: Int { model.children.reduce(0) { $0 + $1.pendingChores } }

    private var familyPage: some View {
        VStack(spacing: 8) {
            Text(tr("🦁 טופי"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(headline)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                stat("\(minutesToday)", tr("דקות היום"), tint: Tofy.mint)
                if choresWaiting > 0 {
                    stat("\(choresWaiting)", tr("מטלות"), tint: Tofy.gold)
                }
            }

            if let t = model.updatedAt {
                Text(tr("עודכן \(t.formatted(date: .omitted, time: .shortened))"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 6)
    }

    private var headline: String {
        if let one = playing.first {
            return playing.count == 1
                ? (one.girl ? tr("\(one.name) משחקת עכשיו") : tr("\(one.name) משחק עכשיו"))
                : tr("\(playing.count) ילדים משחקים עכשיו")
        }
        switch model.children.count {
        case 1: return tr("ילד אחד · אף אחד לא משחק")
        case 2: return tr("שני ילדים · שקט עכשיו")
        default: return tr("\(model.children.count) ילדים · שקט עכשיו")
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

    // MARK: - One child — the glance, then ⚡ actions (Rani, 2026-10-08)

    private func childPage(_ c: WatchChildGlance) -> some View {
        ScrollView {
            VStack(spacing: 7) {
                Text(c.emoji).font(.system(size: 30))

                HStack(spacing: 5) {
                    if c.playingNow {
                        Circle().fill(Tofy.mint).frame(width: 7, height: 7)
                    }
                    Text(c.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }

                Text(c.playingNow ? (c.girl ? tr("משחקת עכשיו") : tr("משחק עכשיו"))
                                  : (c.girl ? tr("לא משחקת כרגע") : tr("לא משחק כרגע")))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(c.playingNow ? Tofy.mint : .white.opacity(0.65))

                // ⚡ One clear button, right under the name (Rani, 2026-10-10: "בשעון
                // אני לא רואה כפתור פעולות") — the three actions used to wait at the
                // very bottom of the page, under a scroll nobody thought to make.
                NavigationLink {
                    actionsPage(c)
                } label: {
                    actionLabel("⚡", tr("פעולות"), fill: Color(tofyHex: "FF5FA8"))
                }
                .buttonStyle(.plain)

                VStack(spacing: 4) {
                    row("🎮", c.girl ? tr("\(c.earnedToday) דקות שהרוויחה היום") : tr("\(c.earnedToday) דקות שהרוויח היום"))
                    if c.pendingChores > 0 {
                        row("🧹", c.pendingChores == 1 ? tr("מטלה מחכה לאישור")
                                                       : tr("\(c.pendingChores) מטלות מחכות"))
                    }
                    if c.moneyBalance > 0 {
                        row("💰", tr("\(Money.pocket(c.moneyBalance)) בקופה"))
                    }
                    if !c.whereText.isEmpty {
                        row("", c.whereText)
                    }
                }
                .padding(.vertical, 8).padding(.horizontal, 9)
                .watchPane(radius: 13, tint: c.playingNow ? Tofy.mint : nil)
            }
            .padding(.horizontal, 6)
        }
    }

    /// The same actions as the phone's "פעולות" — each is sent to the phone.
    private func actionsPage(_ c: WatchChildGlance) -> some View {
        ScrollView {
            VStack(spacing: 7) {
                Text(c.name)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if c.hasDevice {
                    NavigationLink {
                        giftPicker(c)
                    } label: {
                        actionLabel("💝", tr("מתנת דקות"), fill: Color(tofyHex: "FF5FA8"))
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        lockConfirm(c)
                    } label: {
                        actionLabel("🔒", tr("נעילה"), fill: .white.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                }
                if !c.whereText.isEmpty {
                    Button {
                        model.send("beep", childID: c.id)
                    } label: {
                        actionLabel("🔔", tr("צפצוף לטלפון"), fill: .white.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                }
                // Nothing to do from here without a device of the child's own.
                if !c.hasDevice, c.whereText.isEmpty {
                    Text(tr("אין עדיין מכשיר מחובר"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private func actionLabel(_ emoji: String, _ title: String, fill: Color) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 15))
            Text(title).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity).frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
    }

    private func giftPicker(_ c: WatchChildGlance) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(tr("מתנת דקות ל\(c.name)"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                ForEach([(15, tr("רבע שעה")), (30, tr("חצי שעה")), (60, tr("שעה")), (120, tr("שעתיים"))], id: \.0) { m, label in
                    Button {
                        model.send("gift", childID: c.id, minutes: m)
                    } label: {
                        actionLabel("💝", label, fill: Color(tofyHex: "FF5FA8").opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(WatchBackdrop())
    }

    private func lockConfirm(_ c: WatchChildGlance) -> some View {
        VStack(spacing: 8) {
            Text("🔒").font(.system(size: 28))
            Text(tr("לנעול את \(c.name) עכשיו?"))
                .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                model.send("lock", childID: c.id)
            } label: {
                actionLabel("🔒", tr("נעל עכשיו"), fill: Color(tofyHex: "EF4655"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(WatchBackdrop())
    }

    private func row(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            if !emoji.isEmpty { Text(emoji).font(.system(size: 13)) }
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Nothing yet

    private var emptyState: some View {
        VStack(spacing: 7) {
            Text("🦁").font(.system(size: 38))
            Text(tr("טופי"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("פתחו את טופי באייפון פעם אחת — והמשפחה תופיע כאן"))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
    }
}
