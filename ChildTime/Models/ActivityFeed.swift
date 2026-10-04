import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - What a row can be

/// 🔔 One thing that happened around this family's children, as the parent's
/// activity centre shows it.
///
/// A kind is deliberately *structural* — never a sentence. The server records
/// `kind` + a number + a short value, and the device renders the line in the
/// parent's own language. That way a push sent to a Hebrew phone still reads
/// correctly in the feed after the parent switches the app to English, and a
/// household activity doc stays a handful of bytes.
enum ActivityKind: String, Codable, CaseIterable {
    // — the child playing —
    case playStarted
    case playEnded
    case minutesEarned
    case dailyCapReached
    case screenTimeStart
    case screenTimeEnd
    case screenTimeMoved
    // — milestones —
    case streak
    case personalBest
    case levelUp
    case worldUnlocked
    case milestone
    case discovery
    case wheelWin
    // — the child asking for something —
    case helpRequest
    case premiumRequest
    case packRequest
    case timeTransfer
    // — chores —
    case choreWaiting
    case choreApproved
    // — what the parent did from here —
    case giftSent
    case minutesGranted
    case minutesRevoked
    case remoteLock
    case remoteUnlock
    // — account & devices —
    case deviceJoined
    case deviceQuiet
    case inviteRedeemed
    case accountLink
    case parentGate
    case giftNotOpened
    case pinReset
    // — from Tofy —
    case supportReply
    case weeklyReport
    case passEnding
    case tofyMessage
    case alert
    case insight
    case whatsNew
    /// A push we recorded but whose type this build does not know — still shown,
    /// with the notification's own text as the detail, so nothing silently
    /// disappears when the server learns a new kind before the app does.
    case push

    var emoji: String {
        switch self {
        case .playStarted:      return "🎒"
        case .playEnded:        return "🏁"
        case .minutesEarned:    return "⏰"
        case .dailyCapReached:  return "🛑"
        case .screenTimeStart:  return "📱"
        case .screenTimeEnd:    return "🔒"
        case .screenTimeMoved:  return "🔀"
        case .streak:           return "🔥"
        case .personalBest:     return "🏆"
        case .levelUp:          return "👑"
        case .worldUnlocked:    return "🗺️"
        case .milestone:        return "🌟"
        case .discovery:        return "🔭"
        case .wheelWin:         return "🎡"
        case .helpRequest:      return "🙋"
        case .premiumRequest:   return "⭐"
        case .packRequest:      return "🎁"
        case .timeTransfer:     return "🔁"
        case .choreWaiting:     return "🧹"
        case .choreApproved:    return "👍"
        case .giftSent:         return "💝"
        case .minutesGranted:   return "➕"
        case .minutesRevoked:   return "➖"
        case .remoteLock:       return "🔒"
        case .remoteUnlock:     return "🔓"
        case .deviceJoined:     return "📲"
        case .deviceQuiet:      return "💤"
        case .inviteRedeemed:   return "🤝"
        case .accountLink:      return "👨‍👩‍👧"
        case .parentGate:       return "🔑"
        case .giftNotOpened:    return "💝"
        case .pinReset:         return "🔢"
        case .supportReply:     return "💬"
        case .weeklyReport:     return "📊"
        case .passEnding:       return "⏳"
        case .tofyMessage:      return "📬"
        case .alert:            return "⚠️"
        case .insight:          return "💡"
        case .whatsNew:         return "✨"
        case .push:             return "🔔"
        }
    }

    /// The one line the row shows. Parent-facing Hebrew — no niqqud — and
    /// written WITHOUT a gendered verb, because the row is a log entry under the
    /// child's own avatar and name: "עליית רמה", not "עלה/עלתה רמה". That keeps
    /// one string per kind instead of a masculine and a feminine one, and keeps
    /// every translation honest.
    func line(number: Int? = nil, value: String? = nil) -> String {
        let n = number ?? 0
        let v = value ?? ""
        switch self {
        case .playStarted:      return tr("התחלת משחק")
        case .playEnded:        return tr("סבב הסתיים")
        case .minutesEarned:    return tr("עוד \(n) דקות משחק נצברו")
        case .dailyCapReached:  return tr("המגבלה היומית נגמרה")
        case .screenTimeStart:  return tr("זמן המשחק נפתח")
        case .screenTimeEnd:    return tr("זמן המשחק נגמר")
        case .screenTimeMoved:  return tr("זמן המשחק עבר למכשיר אחר")
        case .streak:           return tr("רצף של \(n) תשובות נכונות")
        case .personalBest:     return n > 0 ? tr("שיא אישי חדש: רצף של \(n)") : tr("שיא אישי חדש")
        case .levelUp:          return n > 0 ? tr("עלייה לרמה \(n)") : tr("עליית רמה")
        case .worldUnlocked:    return v.isEmpty ? tr("עולם חדש נפתח") : tr("עולם חדש נפתח: \(v)")
        case .milestone:        return tr("הישג חדש")
        case .discovery:        return v.isEmpty ? tr("גילוי עניין בנושא חדש") : tr("גילוי עניין ב\(v)")
        case .wheelWin:         return tr("זכייה בגלגל המזל")
        case .helpRequest:      return tr("בקשת עזרה בשאלה")
        case .premiumRequest:   return tr("בקשה לטופי+")
        case .packRequest:      return tr("בקשה לחבילת שאלות")
        case .timeTransfer:     return tr("בקשה להעברת דקות בין האחים")
        case .choreWaiting:     return tr("מטלה מחכה לאישור שלכם")
        case .choreApproved:    return tr("אישרתם מטלה")
        case .giftSent:         return tr("שלחתם \(n) דקות מתנה")
        case .minutesGranted:   return tr("הוספתם \(n) דקות משחק")
        case .minutesRevoked:   return tr("הורדתם \(n) דקות משחק")
        case .remoteLock:       return tr("נעלתם את המכשיר מרחוק")
        case .remoteUnlock:     return tr("פתחתם את המכשיר מרחוק")
        case .deviceJoined:     return tr("מכשיר חדש הצטרף למשפחה")
        case .deviceQuiet:      return tr("אין פעילות מהמכשיר כבר \(n) ימים")
        case .inviteRedeemed:   return tr("ההזמנה למשפחה מומשה")
        case .accountLink:      return tr("עדכון בחיבור המשפחה")
        case .parentGate:       return tr("קוד ההורים הוזן במכשיר של הילד")
        case .giftNotOpened:    return tr("המתנה לא נפתחה במכשיר")
        case .pinReset:         return tr("בקשה לאיפוס קוד ההגנה")
        case .supportReply:     return tr("צוות טופי ענה לכם")
        case .weeklyReport:     return tr("הדוח השבועי מוכן")
        case .passEnding:       return tr("מנוי לעולם עומד להסתיים")
        case .tofyMessage:      return tr("הודעה מטופי")
        case .alert:            return tr("התראת מערכת")
        case .insight:          return tr("תובנה על הילדים")
        case .whatsNew:         return tr("גרסה חדשה של טופי")
        case .push:             return tr("עדכון חדש")
        }
    }

    /// Where a tap on this row belongs.
    var destination: ActivityRoute {
        switch self {
        case .choreWaiting, .choreApproved:     return .chores
        case .supportReply:                     return .support
        case .whatsNew:                         return .whatsNew
        default:                                return .child
        }
    }

    /// The `type` / `kind` string a push carries, mapped onto a feed kind. The
    /// server records the same strings, so one table serves both paths.
    static func fromPushType(_ raw: String?) -> ActivityKind? {
        switch raw {
        case "sessionStart":        return .playStarted
        case "sessionEnd":          return .playEnded
        case "milestone":           return .milestone
        case "streak":              return .streak
        case "wheelWin":            return .wheelWin
        case "discovery":           return .discovery
        case "assistRequest", "parentHelp": return .helpRequest
        case "screenTimeStart":     return .screenTimeStart
        case "screenTimeEnd":       return .screenTimeEnd
        case "screenTimeMoved":     return .screenTimeMoved
        case "parentGateOpened":    return .parentGate
        case "playPINForgot":       return .pinReset
        case "giftOpenFailed":      return .giftNotOpened
        case "levelUp":             return .levelUp
        case "worldUnlocked":       return .worldUnlocked
        case "personalBest":        return .personalBest
        case "choreApproval":       return .choreWaiting
        case "support-chat":        return .supportReply
        case "weeklyReport":        return .weeklyReport
        case "premium-request":     return .premiumRequest
        case "pack-request":        return .packRequest
        case "pass-ending":         return .passEnding
        case "gift-start", "gift-day", "campaign": return .tofyMessage
        case "retention-notice":    return .tofyMessage
        case "dupAlert":            return .alert
        case "timeTransferParent", "timeTransferSeller": return .timeTransfer
        case "childLinkRequest", "childLinkApproved": return .accountLink
        default:                    return nil
        }
    }
}

/// Where a tapped row goes. Resolved against the row's child by the screen that
/// presents the feed, so this type stays free of SwiftUI.
enum ActivityRoute: String, Equatable {
    case child
    case chores
    case support
    case whatsNew
}

/// How far a parent→child command got. Only the parent's own commands carry one.
enum ActivityStatus: String, Codable {
    case sending
    case reachedCloud
    case deviceConfirmed
    case failed

    var label: String {
        switch self {
        case .sending:          return tr("שולח…")
        case .reachedCloud:     return tr("☁️ הגיע לענן")
        case .deviceConfirmed:  return tr("✅ המכשיר אישר")
        case .failed:           return tr("לא נשלח — אפשר לנסות שוב")
        }
    }
}

// MARK: - One row

struct ActivityItem: Identifiable, Codable, Equatable {
    var id: String
    var at: Date
    var kind: ActivityKind
    var childID: String?
    var childName: String?
    /// A short free piece of context — the chore's title, the world's name, the
    /// device's name, or (for a recorded push) the notification's own body.
    var value: String?
    var number: Int?
    var status: ActivityStatus?

    init(id: String? = nil, at: Date, kind: ActivityKind, childID: String? = nil,
         childName: String? = nil, value: String? = nil, number: Int? = nil,
         status: ActivityStatus? = nil) {
        self.id = id ?? ActivityItem.autoID(kind: kind, childID: childID, at: at)
        self.at = at
        self.kind = kind
        self.childID = childID
        self.childName = childName
        self.value = value
        self.number = number
        self.status = status
    }

    static func autoID(kind: ActivityKind, childID: String?, at: Date) -> String {
        "\(kind.rawValue).\(childID ?? "-").\(Int(at.timeIntervalSince1970))"
    }

    var title: String { kind.line(number: number, value: value) }

    /// The quieter second line: the push's own text, or the piece of context the
    /// title did not already use.
    var detail: String? {
        if let s = status { return s.label }
        guard let v = value, !v.isEmpty else { return nil }
        switch kind {
        // These kinds already spell the value into their title.
        case .worldUnlocked, .discovery: return nil
        default: return v
        }
    }

    /// Two records describe the same happening when they agree on kind + child +
    /// context and land within three minutes of each other. That is how the
    /// locally-recorded arrival of a push and the server's record of having sent
    /// it collapse into one row.
    func sameHappening(as other: ActivityItem) -> Bool {
        guard kind == other.kind, childID == other.childID else { return false }
        if kind == .push { return id == other.id }
        return abs(at.timeIntervalSince(other.at)) < 180
    }

    /// Newest first, one row per happening, capped.
    static func merged(_ raw: [ActivityItem], cap: Int = 120) -> [ActivityItem] {
        var kept: [ActivityItem] = []
        var seenIDs = Set<String>()
        for item in raw.sorted(by: { $0.at > $1.at }) {
            if seenIDs.contains(item.id) { continue }
            // A locally-recorded row wins ties only on its extra detail, so
            // merge what the duplicate knows rather than dropping it blind.
            if let idx = kept.lastIndex(where: { $0.sameHappening(as: item) }) {
                if kept[idx].value == nil { kept[idx].value = item.value }
                if kept[idx].number == nil { kept[idx].number = item.number }
                if kept[idx].status == nil { kept[idx].status = item.status }
                continue
            }
            seenIDs.insert(item.id)
            kept.append(item)
            if kept.count >= cap { break }
        }
        return kept
    }
}

// MARK: - The on-device log

/// Everything this device itself saw or did: a push that arrived, a local
/// insight notification that fired, a gift or a remote lock the parent sent from
/// here. A capped ring buffer in `UserDefaults` — the same place every other
/// per-device flag lives — so the feed works with no network and costs no reads.
///
/// First-party by construction: it never leaves the device and is never sent
/// anywhere. (Kids Category: zero third-party analytics.)
@MainActor
enum ActivityLog {
    private static let logKey  = "activity.log"
    private static let readKey = "activity.lastReadAt"
    private static let cap = 160

    private static var cache: [ActivityItem]?

    static var items: [ActivityItem] {
        if let cache { return cache }
        guard let data = UserDefaults.standard.data(forKey: logKey),
              let decoded = try? JSONDecoder().decode([ActivityItem].self, from: data) else {
            cache = []
            return []
        }
        cache = decoded
        return decoded
    }

    private static func save(_ list: [ActivityItem]) {
        let trimmed = Array(list.sorted(by: { $0.at > $1.at }).prefix(cap))
        cache = trimmed
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
    }

    /// Record one happening. Returns the row's id so a sender can mark the
    /// command's progress on it later.
    @discardableResult
    static func record(_ kind: ActivityKind, childID: String? = nil, childName: String? = nil,
                       value: String? = nil, number: Int? = nil, status: ActivityStatus? = nil,
                       id: String? = nil, at: Date = Date()) -> String {
        // A screenshot / design run shows a seeded feed (see
        // `ActivityFeedStore.seedDemo`) and must never write into the real log.
        guard !AppInfo.isDemoRun else { return "" }
        let item = ActivityItem(id: id, at: at, kind: kind, childID: childID,
                                childName: childName, value: value, number: number, status: status)
        var list = items.filter { $0.id != item.id }
        list.append(item)
        save(list)
        ActivityFeedStore.shared.refreshSoon()
        return item.id
    }

    /// Move a recorded command along its delivery chain (sent → cloud → device).
    static func update(id: String, status: ActivityStatus) {
        guard !id.isEmpty, !AppInfo.isDemoRun else { return }
        var list = items
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        // Never walk a confirmation backwards.
        if list[idx].status == .deviceConfirmed, status != .failed { return }
        list[idx].status = status
        save(list)
        ActivityFeedStore.shared.refreshSoon()
    }

    /// A notification that arrived on (or is still sitting on) this device.
    /// `identifier`-keyed so the same banner swept twice stays one row.
    static func recordNotification(type: String?, identifier: String, body: String?, at: Date) {
        var kind = ActivityKind.fromPushType(type)
        if kind == nil, identifier.hasPrefix("insight.") { kind = .insight }
        let resolved = kind ?? .push
        record(resolved,
               value: (body?.isEmpty == false) ? body : nil,
               id: "push.\(identifier)",
               at: at)
    }

    // MARK: Read state

    static var lastReadAt: Date {
        let raw = UserDefaults.standard.double(forKey: readKey)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : .distantPast
    }

    static var hasReadMark: Bool { UserDefaults.standard.double(forKey: readKey) > 0 }

    static func markRead(_ when: Date = Date()) {
        UserDefaults.standard.set(when.timeIntervalSince1970, forKey: readKey)
    }

    /// Tests and a deliberate device reset.
    static func reset() {
        cache = nil
        UserDefaults.standard.removeObject(forKey: logKey)
        UserDefaults.standard.removeObject(forKey: readKey)
    }
}

// MARK: - Rows derived from state the app already holds

/// Pure: turns the stores' *current* state into feed rows, with no new write
/// path and no extra query. A chore waiting for approval, a device that joined,
/// a device that went quiet, the minutes earned today — all of it is already
/// mirrored into memory for the dashboard, so the feed just reads it.
enum ActivityDerived {
    struct Input {
        var now: Date = Date()
        var children: [(id: UUID, name: String)] = []
        var snapshots: [UUID: ProgressSnapshot] = [:]
        var caps: [UUID: Int] = [:]              // resolved daily cap per child (0 = off)
        var chores: [Chore] = []
        var devices: [String: [ChildDevice]] = [:]
        var supportUnread: Int = 0
    }

    /// A device with nothing for this long is worth telling the parent about.
    static let quietDays = 3
    /// How far back a derived row may reach.
    static let window: TimeInterval = 14 * 86_400

    static func items(_ input: Input) -> [ActivityItem] {
        var out: [ActivityItem] = []
        let names = Dictionary(input.children.map { ($0.id.uuidString, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        let cutoff = input.now.addingTimeInterval(-window)

        // 🧹 Chores — waiting for the parent, and what was approved lately.
        for chore in input.chores where !chore.archived {
            let label = "\(chore.emoji) \(chore.title)"
            if let marked = chore.markedDoneAt {
                let at = Date(timeIntervalSince1970: marked)
                if at > cutoff {
                    out.append(ActivityItem(id: "chore.wait.\(chore.id).\(Int(marked))", at: at,
                                            kind: .choreWaiting, childID: chore.childID,
                                            childName: names[chore.childID], value: label,
                                            number: chore.rewardMinutes))
                }
            }
            if let approved = chore.lastApprovedAt {
                let at = Date(timeIntervalSince1970: approved)
                if at > cutoff {
                    out.append(ActivityItem(id: "chore.ok.\(chore.id).\(Int(approved))", at: at,
                                            kind: .choreApproved, childID: chore.childID,
                                            childName: names[chore.childID], value: label,
                                            number: chore.rewardMinutes))
                }
            }
        }

        // 📲 Devices — joined, and gone quiet.
        for (childID, list) in input.devices {
            for device in list {
                if device.joinedAt > cutoff {
                    out.append(ActivityItem(id: "device.join.\(device.id)", at: device.joinedAt,
                                            kind: .deviceJoined, childID: childID,
                                            childName: names[childID], value: device.name))
                }
                let quiet = input.now.timeIntervalSince(device.lastSeenAt) / 86_400
                if quiet >= Double(quietDays), device.lastSeenAt > cutoff {
                    out.append(ActivityItem(id: "device.quiet.\(device.id)", at: device.lastSeenAt,
                                            kind: .deviceQuiet, childID: childID,
                                            childName: names[childID], value: device.name,
                                            number: Int(quiet)))
                }
            }
        }

        // ⏰ Today's minutes, and the daily limit running out.
        for child in input.children {
            let id = child.id
            let name = child.name
            guard let snapshot = input.snapshots[id] else { continue }
            guard let day = snapshot.dailyEarnedDate,
                  Calendar.current.isDate(day, inSameDayAs: input.now) else { continue }
            let at = min(snapshot.lastModifiedAt, input.now)
            if snapshot.minutesEarnedToday > 0 {
                out.append(ActivityItem(id: "earned.\(id.uuidString).\(dayKey(day))", at: at,
                                        kind: .minutesEarned, childID: id.uuidString,
                                        childName: name, number: snapshot.minutesEarnedToday))
            }
            let cap = input.caps[id] ?? 0
            if cap > 0, snapshot.netUnlockedToday >= cap {
                out.append(ActivityItem(id: "cap.\(id.uuidString).\(dayKey(day))", at: at,
                                        kind: .dailyCapReached, childID: id.uuidString,
                                        childName: name, number: cap))
            }
        }

        // 💬 A team reply we are still holding, in case its push never landed here.
        if input.supportUnread > 0 {
            out.append(ActivityItem(id: "support.unread", at: input.now, kind: .supportReply))
        }

        return out
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

// MARK: - Standing offers (what used to sit above the children)

/// Where a tapped offer goes. The screen that presents the feed owns the actual
/// navigation, so this type stays free of SwiftUI — same shape as `ActivityRoute`.
enum ActivityOfferAction: Equatable {
    case none
    case paywall(source: String)
    case manageSubscription
    /// A world pass or a question pack, by `QuestionPack.id`, for one child.
    case pack(id: String, childID: String?)
    case notificationSettings
}

/// 🎁 A standing offer or notice — Tofy+, the gift journey, a child's request,
/// "notifications are off".
///
/// These used to stack ABOVE the children's cards on the parent home and push
/// them down the screen; the children are the point of that screen, so they live
/// here now (Rani). An offer is NOT something that happened: it carries no
/// timestamp, never counts toward the unread badge, and is never stored. It is
/// derived live from the very state the panes read, which is what keeps it from
/// flooding the feed — exactly one row per offer, replaced rather than repeated,
/// and gone the moment the offer is.
struct ActivityOffer: Identifiable, Equatable {
    var id: String
    var emoji: String
    var title: String
    var detail: String?
    var action: ActivityOfferAction = .none
    /// Gold = the Tofy+ family of offers; plain glass = a notice.
    var gold: Bool = false
}

/// Pure: the offers that apply right now.
enum ActivityOffers {
    struct Input {
        var now: Date = Date()
        var isPremium = false
        var introEligible = false
        var notificationsOn = true
        var children: [Profile] = []
        /// `households/{id}` conversion journey.
        var giftUntil: Date?
        var giftStarted = false
        var giftEnded = false
        var activation: ActivationProgress?
        /// Children who tapped "ask a parent" on their own device.
        var premiumAskers: [Profile] = []
        var premiumTopics: [UUID: String] = [:]
        var packAskers: [(child: Profile, pack: QuestionPack)] = []
        /// Best child by answered questions — the one the gift copy talks about.
        var star: (profile: Profile, snapshot: ProgressSnapshot)?
    }

    static func current(_ input: Input) -> [ActivityOffer] {
        var out: [ActivityOffer] = []

        // A child's own request comes first — it is the reason the parent opened
        // the app at all.
        if !input.isPremium, !input.premiumAskers.isEmpty {
            // "רוצה" is spelled the same for a boy and for a girl once the
            // niqqud is gone — which is how one string serves both.
            var title = tr("\(input.premiumAskers.map(\.name).joined(separator: tr(" ו"))) רוצים טופי+")
            if input.premiumAskers.count == 1, let p = input.premiumAskers.first {
                title = tr("\(p.name) רוצה טופי+")
            }
            var emoji = "👑"
            var detail = tr("מנוי אחד לכל המשפחה — נפתח מכאן, בטלפון שלכם")
            var action = ActivityOfferAction.paywall(source: "child_request")
            if input.premiumAskers.count == 1, let p = input.premiumAskers.first,
               let raw = input.premiumTopics[p.id], let topic = Topic(rawValue: raw),
               let pass = WorldPasses.pass(for: topic) {
                emoji = topic.emoji
                detail = tr("\(topic.displayName) — עולם בודד ל-30 יום, או טופי+ לכל המשפחה")
                action = .pack(id: pass.id, childID: p.id.uuidString)
            }
            out.append(ActivityOffer(id: "offer.premiumRequest", emoji: emoji,
                                     title: title,
                                     detail: detail, action: action, gold: true))
        }
        for row in input.packAskers {
            out.append(ActivityOffer(id: "offer.pack.\(row.child.id.uuidString).\(row.pack.id)",
                                     emoji: row.pack.emoji,
                                     title: tr("\(row.child.name) רוצה את \(row.pack.name)"),
                                     detail: tr("שאלון חדש · תוספת · נפתח מכאן, בטלפון שלכם"),
                                     action: .pack(id: row.pack.id, childID: row.child.id.uuidString),
                                     gold: false))
        }

        // The conversion journey — one row for wherever the family stands.
        if let until = input.giftUntil, until > input.now {
            let days = max(0, Int(ceil(until.timeIntervalSince(input.now) / 86_400)))
            if days > 7 {
                out.append(ActivityOffer(id: "offer.gift", emoji: "🎁",
                                         title: tr("טופי+ במתנה — עוד \(days) ימים"),
                                         detail: tr("כל העולמות פתוחים עד \(shortDate(until)). בלי כרטיס, לא מתחדש."),
                                         action: .none, gold: true))
            } else {
                var detail = tr("אפשר להשאיר את כל העולמות פתוחים")
                if let star = input.star, star.snapshot.totalAnswered > 0 {
                    let s = star.snapshot
                    let worlds = s.topicAnswered.values.filter { $0 > 0 }.count
                    let accuracy = Int((Double(s.totalCorrect) / Double(s.totalAnswered) * 100).rounded())
                    detail = tr("\(worlds) עולמות · \(s.totalAnswered) שאלות · \(accuracy)% הצלחה — אפשר להשאיר הכל פתוח")
                }
                out.append(ActivityOffer(id: "offer.gift", emoji: "🎁",
                                         title: tr("המתנה מסתיימת ב-\(shortDate(until))"),
                                         detail: detail,
                                         action: .paywall(source: "gift_card"), gold: true))
            }
        } else if !input.isPremium, !input.giftStarted,
                  let a = input.activation, a.questions > 0, let star = input.star {
            let next = a.daysLeft > 0
                ? tr("\(star.profile.name) · \(a.questions) שאלות עד עכשיו · עוד \(a.daysLeft) ימים פעילים")
                : tr("\(star.profile.name) · \(a.questions) שאלות עד עכשיו · עוד \(a.questionsLeft) שאלות")
            out.append(ActivityOffer(id: "offer.activation", emoji: "🎉",
                                     title: tr("עוד קצת וטופי+ ייפתח לכם במתנה"),
                                     detail: next, action: .none, gold: true))
        } else if input.isPremium {
            out.append(ActivityOffer(id: "offer.tofyPlus", emoji: "👑",
                                     title: tr("טופי+ פעיל"),
                                     detail: tr("לכל המשפחה · ניהול המנוי"),
                                     action: .manageSubscription, gold: true))
        } else {
            out.append(ActivityOffer(id: "offer.tofyPlus", emoji: "👑",
                                     title: tr("טופי+ לכל המשפחה"),
                                     detail: input.introEligible
                                        ? tr("כל העולמות, המשחקים והמטלות, לכל הילדים ובכל המכשירים · 7 ימים חינם")
                                        : tr("כל העולמות, המשחקים והמטלות, לכל הילדים ובכל המכשירים"),
                                     action: .paywall(source: "activity_center"), gold: true))
        }

        // 🔔 Notifications off — the one notice that belongs here more than it
        // ever belonged on the home: this IS the page about notifications.
        if !input.notificationsOn {
            out.append(ActivityOffer(id: "offer.notifications", emoji: "🔕",
                                     title: tr("ההתראות כבויות"),
                                     detail: tr("הפעילו כדי לדעת מיד כשמשהו קורה אצל הילדים"),
                                     action: .notificationSettings, gold: false))
        }
        return out
    }

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f.string(from: d)
    }
}

// MARK: - The store the bell and the screen read

/// Merges the three sources into one feed and keeps the unread count.
///
/// Cost control: the cloud listener is attached only from `start()`, which the
/// parent home calls from a `.task` AFTER its first frame, and it asks for at
/// most `cloudLimit` documents of one household-scoped collection. Nothing here
/// runs before the home screen is on screen, and everything still works from
/// the local log alone when there is no network.
@MainActor
final class ActivityFeedStore: ObservableObject {
    static let shared = ActivityFeedStore()

    /// Newest first, already merged and capped.
    @Published private(set) var items: [ActivityItem] = []
    /// Rows newer than the parent's last visit. Offers are never counted — a
    /// standing offer would keep the badge lit for ever.
    @Published private(set) var unread: Int = 0
    /// 🎁 The standing offers that used to sit above the children's cards.
    @Published private(set) var offers: [ActivityOffer] = []
    /// Whether the worlds / packs shelf has anything to show down there.
    @Published private(set) var showsPacksShelf = false

    static let cloudLimit = 60

    private var cloudItems: [ActivityItem] = []
    private var demoItems: [ActivityItem]?
    /// A demo run never touches the stored read mark — it keeps its own.
    private var demoReadAt: Date?
    /// A demo run shows the offers too (they are half the screen's story).
    private var demoOffers = false
    private var started = false
    private var bag = Set<AnyCancellable>()
    private var pendingRefresh = false
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    private var listeningHousehold: String?
    #endif

    private init() {}

    // MARK: Lifecycle

    /// Idempotent. Safe to call from every appear — and deliberately NOT called
    /// before the first frame.
    func start() {
        guard !started else { refreshSoon(); return }
        started = true

        // A fresh install (or the first build with the bell) starts read: the
        // parent should not meet a badge counting history they never missed.
        if !ActivityLog.hasReadMark { ActivityLog.markRead() }
        noteBuildIfNew()

        // Re-derive when any of the stores the feed reads changes. Debounced, so
        // a burst of Firestore snapshots costs one pass.
        ChoreStore.shared.$chores
            .map { _ in () }
            .merge(with: HouseholdManager.shared.$devicesByChild.map { _ in () })
            .merge(with: RemoteSyncManager.shared.$remoteSnapshots.map { _ in () })
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)

        HouseholdManager.shared.$household
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] _ in self?.attachCloudListener() }
            .store(in: &bag)

        attachCloudListener()
        refresh()
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        listeningHousehold = nil
        #endif
        bag.removeAll()
        started = false
    }

    /// Coalesce several records in one turn into a single recompute.
    func refreshSoon() {
        guard !pendingRefresh else { return }
        pendingRefresh = true
        Task { @MainActor in
            self.pendingRefresh = false
            self.refresh()
        }
    }

    // MARK: Building the feed

    func refresh() {
        if let demoItems {
            items = ActivityItem.merged(demoItems)
            unread = items.filter { $0.at > readMark }.count
            if demoOffers {
                offers = ActivityOffers.current(offersInput())
                showsPacksShelf = true
            }
            return
        }
        offers = ActivityOffers.current(offersInput())
        showsPacksShelf = packsShelfApplies
        let derived = ActivityDerived.items(derivedInput())
        items = ActivityItem.merged(ActivityLog.items + cloudItems + derived)
        let since = readMark
        unread = items.filter { $0.at > since }.count
    }

    /// When the parent last looked. The screen keeps the dots of what was new
    /// visible while they read, so it reads this once on appear.
    var readMark: Date { demoReadAt ?? ActivityLog.lastReadAt }

    private func derivedInput() -> ActivityDerived.Input {
        var input = ActivityDerived.Input()
        let profiles = ProfileStore.shared.profiles
        input.children = profiles.map { (id: $0.id, name: $0.name) }
        let settings = ParentSettings.shared
        for p in profiles {
            let cap = p.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled,
                                         globalMax: settings.maxMinutesPerDay)
            input.caps[p.id] = cap.enabled ? cap.minutes : 0
            if let remote = RemoteSyncManager.shared.remoteSnapshots[p.id] {
                input.snapshots[p.id] = remote
            } else {
                input.snapshots[p.id] = ProgressVault.shared.snapshot(for: p.id)
            }
        }
        input.chores = ChoreStore.shared.chores
        input.devices = HouseholdManager.shared.devicesByChild
        input.supportUnread = SupportChatStore.shared.parentUnread
        return input
    }

    /// Everything the standing offers are decided from. Cheap: all of it is
    /// already in memory for the parent home.
    private func offersInput() -> ActivityOffers.Input {
        var input = ActivityOffers.Input()
        let profiles = ProfileStore.shared.profiles
        let subs = SubscriptionManager.shared
        let remote = RemoteSyncManager.shared
        input.children = profiles
        input.isPremium = subs.isPremium
        input.introEligible = subs.yearlyIntroEligible
        input.notificationsOn = PushManager.shared.authorized
        if let hh = HouseholdManager.shared.household {
            if hh.premiumSource == "gift" { input.giftUntil = hh.giftUntil ?? hh.premiumUntil }
            input.giftStarted = hh.giftStartedAt != nil
            input.giftEnded = hh.giftEndedAt != nil
            input.activation = hh.activation
        }
        input.premiumAskers = profiles.filter { remote.premiumRequests[$0.id] != nil }
        input.premiumTopics = remote.premiumRequestTopics
        input.packAskers = profiles.compactMap { p in
            guard let id = remote.packRequests[p.id], let pack = QuestionPacks.find(id),
                  !p.owns(pack) else { return nil }
            return (child: p, pack: pack)
        }
        // The child with the most play — the one the gift copy talks about.
        var best: (profile: Profile, snapshot: ProgressSnapshot)?
        for p in profiles {
            let snap = remote.remoteSnapshots[p.id] ?? ProgressVault.shared.snapshot(for: p.id)
            if snap.totalAnswered > (best?.snapshot.totalAnswered ?? -1) { best = (p, snap) }
        }
        input.star = best
        return input
    }

    /// 🌍 The one-time doors (30-day worlds, packs) are the fallback for a family
    /// that will not subscribe — the same founder knob the home used: shown only
    /// once the gift has ended, never beside it.
    private var packsShelfApplies: Bool {
        if SubscriptionManager.shared.isPremium { return true }
        if !ConversionConfig.shared.oneTimeAfterGiftOnly { return true }
        return HouseholdManager.shared.household?.giftEndedAt != nil
    }

    // MARK: Read state

    func markRead() {
        if demoItems == nil { ActivityLog.markRead() }
        unread = 0
    }

    // MARK: ✨ What's new

    /// The first run of a new build records one "what's new" row, so the feed has
    /// a real timestamp for it (the release notes themselves carry no date) and
    /// the row can open the story rather than repeat it.
    private func noteBuildIfNew() {
        let key = "activity.whatsNewBuild"
        let seen = UserDefaults.standard.string(forKey: key)
        let token = WhatsNewContent.seenToken
        guard seen != token else { return }
        UserDefaults.standard.set(token, forKey: key)
        guard seen != nil else { return }   // a fresh install has no "new" yet
        let headline = WhatsNewContent.releases.first?.headline
        ActivityLog.record(.whatsNew, value: headline, id: "whatsNew.\(token)")
    }

    // MARK: Cloud

    private func attachCloudListener() {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return }
        guard let hid = HouseholdManager.shared.household?.id else { return }
        guard listeningHousehold != hid else { return }
        listener?.remove()
        listeningHousehold = hid
        listener = Firestore.firestore()
            .collection("households").document(hid)
            .collection("activity")
            .order(by: "at", descending: true)
            .limit(to: Self.cloudLimit)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                self.cloudItems = snap.documents.compactMap { ActivityItem(cloud: $0.documentID, data: $0.data()) }
                self.refresh()
            }
        #endif
    }

    // MARK: Demo

    /// DEMO_SCREEN=notifications — a seeded feed for screenshots. Nothing is
    /// written to the real log and no listener is attached.
    func seedDemo(children: [(id: UUID, name: String)]) {
        guard demoItems == nil else { return }   // idempotent: body may run again
        let now = Date()
        let first = children.first
        let second = children.count > 1 ? children[1] : children.first
        func item(_ minutesAgo: Double, _ kind: ActivityKind,
                  _ who: (id: UUID, name: String)?, value: String? = nil,
                  number: Int? = nil, status: ActivityStatus? = nil) -> ActivityItem {
            ActivityItem(at: now.addingTimeInterval(-minutesAgo * 60), kind: kind,
                         childID: who?.id.uuidString, childName: who?.name,
                         value: value, number: number, status: status)
        }
        demoItems = [
            item(4,    .choreWaiting,   second, value: tr("🧹 לסדר את החדר"), number: 20),
            item(26,   .minutesEarned,  first,  number: 35),
            item(41,   .screenTimeStart, first),
            item(55,   .giftSent,       second, number: 15, status: .deviceConfirmed),
            item(90,   .streak,         first,  number: 12),
            item(140,  .helpRequest,    second, value: tr("כמה זה 7 × 8?")),
            item(190,  .dailyCapReached, first, number: 60),
            item(260,  .supportReply,   nil,    value: tr("שמחים לעזור — שלחנו לכם הסבר במסך הצ'אט.")),
            item(1_520, .levelUp,       first,  number: 7),
            item(1_610, .remoteLock,    second, status: .deviceConfirmed),
            item(1_700, .worldUnlocked, first,  value: Worlds.all.first?.name),
            item(1_880, .choreApproved, second, value: tr("🪴 להשקות את העציצים"), number: 10),
            item(2_900, .deviceJoined,  second, value: "iPad"),
            item(3_050, .whatsNew,      nil,    value: WhatsNewContent.releases.first?.headline),
            item(4_400, .weeklyReport,  first),
        ]
        demoReadAt = now.addingTimeInterval(-60 * 60)   // a few unread, for the badge
        demoOffers = true
        refresh()
    }

    /// DEMO_SCREEN=notificationsempty — the empty state, as a first-week family
    /// with nothing recorded yet sees it.
    func seedDemoEmpty() {
        guard demoItems == nil else { return }
        demoItems = []
        demoReadAt = Date()
        refresh()
    }
}

#if canImport(FirebaseFirestore)
extension ActivityItem {
    /// `households/{hid}/activity/{id}` — written by the Cloud Function that
    /// sends the parent's push, so the row survives a banner nobody saw.
    init?(cloud id: String, data: [String: Any]) {
        guard let seconds = data["at"] as? Double else { return nil }
        let raw = (data["kind"] as? String) ?? (data["type"] as? String)
        let kind = ActivityKind(rawValue: raw ?? "") ?? ActivityKind.fromPushType(raw) ?? .push
        self.init(id: "hh.\(id)",
                  at: Date(timeIntervalSince1970: seconds),
                  kind: kind,
                  childID: data["childID"] as? String,
                  childName: data["childName"] as? String,
                  value: data["value"] as? String,
                  number: (data["num"] as? Int) ?? (data["num"] as? NSNumber)?.intValue)
    }
}
#endif

// MARK: - Grouping for the screen

/// "היום" / "אתמול" / a date — one section of the feed.
struct ActivityDay: Identifiable {
    var id: String
    var title: String
    var items: [ActivityItem]

    /// Groups newest-first rows into day sections, newest day first.
    static func group(_ items: [ActivityItem], now: Date = Date(),
                      calendar: Calendar = .current) -> [ActivityDay] {
        var order: [String] = []
        var buckets: [String: [ActivityItem]] = [:]
        for item in items {
            let c = calendar.dateComponents([.year, .month, .day], from: item.at)
            let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key]?.append(item)
        }
        return order.compactMap { key in
            guard let rows = buckets[key], let first = rows.first else { return nil }
            return ActivityDay(id: key, title: title(for: first.at, now: now, calendar: calendar), items: rows)
        }
    }

    static func title(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return tr("היום") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return tr("אתמול") }
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }
}
