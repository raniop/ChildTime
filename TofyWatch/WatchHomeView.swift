import SwiftUI
import WatchConnectivity
import WatchKit

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

/// 📶 Where the last gift / lock sent from the wrist stands — the same chain the
/// phone shows: sending → sent → the child's device confirmed (Rani, 2026-10-10).
struct WatchActionStatus: Equatable {
    enum State: String {
        /// `willNotify`: sent, and no answer on the wrist yet — the phone's
        /// notification ("המתנה הגיעה") is what tells the rest.
        case sending, queued, sent, willNotify, confirmed, failed
        /// Later states win; an older message never takes a newer one back.
        var rank: Int {
            switch self {
            case .sending: return 0
            case .queued: return 1
            case .sent: return 2
            case .willNotify: return 3
            case .confirmed: return 4
            case .failed: return 5
            }
        }
    }
    /// The phone's id for it — nil until the phone answers.
    var id: String?
    let childID: String
    let kind: String        // "gift" | "lock"
    var minutes: Int
    var state: State
    let startedAt: Date
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
            // WATCH_DEMO_STATUS=sending|sent|confirmed|willNotify — the status row.
            if let raw = ProcessInfo.processInfo.environment["WATCH_DEMO_STATUS"],
               let state = WatchActionStatus.State(rawValue: raw) {
                action = WatchActionStatus(id: "demo", childID: "1", kind: "gift", minutes: 30,
                                           state: state, startedAt: Date())
            }
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

    /// "נשלח ✓" / "האייפון לא זמין כרגע" — for the beep, and for what can't even start.
    @Published var note: String?
    /// The last gift / lock and how far it got (see `WatchActionStatus`).
    @Published var action: WatchActionStatus?

    /// ⚡ Ask the phone to do it (gift / lock / beep). Live when the phone is in
    /// reach; otherwise queued, and it runs when they reconnect.
    func send(_ action: String, childID: String, minutes: Int = 0) {
        var msg: [String: Any] = ["action": action, "childID": childID]
        if minutes > 0 { msg["minutes"] = minutes }
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { show(tr("האייפון לא זמין כרגע")); return }
        // The beep has no answer to wait for — a short note is all there is to say.
        let tracked = action == "gift" || action == "lock"
        let started = Date()
        if tracked {
            DispatchQueue.main.async {
                self.action = WatchActionStatus(id: nil, childID: childID, kind: action, minutes: minutes,
                                                state: .sending, startedAt: started)
            }
            armTimeout(for: started)
        }
        func queued() {
            session.transferUserInfo(msg)
            if tracked { advance(startedAt: started) { $0.state = .queued } }
            else { show(tr("יישלח כשהאייפון יתחבר")) }
        }
        guard session.isReachable else { queued(); return }
        session.sendMessage(msg, replyHandler: { r in
            let ok = r["ok"] as? Bool ?? false
            guard tracked else { self.show(ok ? tr("נשלח ✓") : tr("לא הצליח — נסו מהאייפון")); return }
            self.advance(startedAt: started) {
                guard ok else { $0.state = .failed; return }
                $0.id = r["actionID"] as? String
                if let m = r["minutes"] as? Int, m > 0 { $0.minutes = m }   // capped at midnight
            }
        }, errorHandler: { _ in queued() })
    }

    /// Change the action that began at `startedAt` — if it is still the current one.
    private func advance(startedAt: Date, _ change: @escaping (inout WatchActionStatus) -> Void) {
        DispatchQueue.main.async {
            guard var a = self.action, a.startedAt == startedAt else { return }
            change(&a); self.action = a
        }
    }

    /// 20 seconds without the child's device answering ON THE WRIST: say what is
    /// true — it was sent, and a notification follows — and then get out of the
    /// way. (The first version said "the device is unavailable" here and kept
    /// saying it for good, about a gift the child had already received: the
    /// phone had gone back to sleep before the answer came — Rani, 2026-10-10.)
    private func armTimeout(for startedAt: Date) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            guard var a = self.action, a.startedAt == startedAt else { return }
            switch a.state {
            case .sent: a.state = .willNotify
            case .sending: a.state = .queued          // the PHONE hasn't reached the cloud yet
            default: return
            }
            self.action = a
        }
        // Whatever it says by then, the row never stays: a minute and a half, and it clears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
            if self.action?.startedAt == startedAt { withAnimation { self.action = nil } }
        }
    }

    /// Timers don't run while the watch app sleeps — so on every wake, a row
    /// older than two minutes is simply dropped.
    func dropStaleAction() {
        if let a = action, Date().timeIntervalSince(a.startedAt) > 120 { action = nil }
    }

    /// The phone's word on an action: live (`didReceiveMessage`) or in the snapshot.
    private func applyStatus(_ st: [String: Any]) {
        guard let id = st["id"] as? String, let raw = st["state"] as? String,
              let state = WatchActionStatus.State(rawValue: raw) else { return }
        DispatchQueue.main.async {
            guard var a = self.action else { return }
            // Ours: the id the phone gave us — or, before its reply landed, the
            // same child and kind, stamped after we sent it.
            let mine = a.id == id || (a.id == nil
                && a.childID == (st["childID"] as? String) && a.kind == (st["kind"] as? String)
                && (st["at"] as? Double ?? 0) >= a.startedAt.timeIntervalSince1970 - 2)
            guard mine, state.rank > a.state.rank else { return }
            a.id = id; a.state = state
            self.action = a
            if state == .confirmed {
                WKInterfaceDevice.current().play(.success)
                // It has been said — half a minute later the row makes room again.
                let started = a.startedAt
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    if self.action?.startedAt == started { withAnimation { self.action = nil } }
                }
            } else if state == .failed {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let st = message["actionStatus"] as? [String: Any] { applyStatus(st) }
    }

    private func show(_ text: String) {
        DispatchQueue.main.async {
            self.note = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { if self.note == text { self.note = nil } }
        }
    }

    private func apply(_ ctx: [String: Any]) {
        if let st = ctx["actionStatus"] as? [String: Any] { applyStatus(st) }
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
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.dropStaleAction() } }
        .onAppear { model.dropStaleAction() }
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
                if let a = model.action, a.childID == c.id {
                    statusRow(a, child: c)
                        .transition(.opacity)
                }
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

    /// 📶 One row, always in the same place: what was sent, and how far it got.
    private func statusRow(_ a: WatchActionStatus, child c: WatchChildGlance) -> some View {
        let title = a.kind == "gift" ? "💝 " + tr("\(a.minutes) דק׳") : "🔒 " + tr("נעילה")
        let line: String, icon: String, fill: Color
        switch a.state {
        case .sending:     line = tr("שולח…"); icon = ""; fill = .white.opacity(0.18)
        case .queued:      line = tr("יישלח כשהאייפון יתחבר"); icon = "⏳"; fill = .white.opacity(0.18)
        case .sent:        line = tr("נשלח, מחכה למכשיר"); icon = "☁️"; fill = .white.opacity(0.18)
        case .confirmed:   line = tr("המכשיר של \(c.name) אישר"); icon = "✅"; fill = Color(tofyHex: "48C774").opacity(0.55)
        case .willNotify:  line = tr("נשלח, נודיע כשיתקבל"); icon = "🔔"; fill = .white.opacity(0.18)
        case .failed:      line = tr("לא הצליח — נסו מהאייפון"); icon = "⚠️"; fill = Color(tofyHex: "FFB84D").opacity(0.5)
        }
        return HStack(spacing: 7) {
            if icon.isEmpty { ProgressView().tint(.white).frame(width: 18, height: 18) }
            else { Text(icon).font(.system(size: 15)) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(line).font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
        .animation(.easeInOut(duration: 0.25), value: a.state)
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
        // Chosen → back to the actions page, where the status row tells the rest.
        SelfClosing { close in
        ScrollView {
            VStack(spacing: 6) {
                Text(tr("מתנת דקות ל\(c.name)"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                ForEach([(15, tr("רבע שעה")), (30, tr("חצי שעה")), (60, tr("שעה")), (120, tr("שעתיים"))], id: \.0) { m, label in
                    Button {
                        model.send("gift", childID: c.id, minutes: m)
                        close()
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
    }

    private func lockConfirm(_ c: WatchChildGlance) -> some View {
        SelfClosing { close in
        VStack(spacing: 8) {
            Text("🔒").font(.system(size: 28))
            Text(tr("לנעול את \(c.name) עכשיו?"))
                .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                model.send("lock", childID: c.id)
                close()
            } label: {
                actionLabel("🔒", tr("נעל עכשיו"), fill: Color(tofyHex: "EF4655"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(WatchBackdrop())
        }
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

/// A pushed page that closes itself once its one job is done.
private struct SelfClosing<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: (_ close: @escaping () -> Void) -> Content
    var body: some View { content { dismiss() } }
}
