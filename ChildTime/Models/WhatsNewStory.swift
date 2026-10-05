import Foundation

/// 📖 "מה חדש" as a STORY — the format a child already knows from every other
/// app on the phone: full-bleed art, thin segments across the top, it advances
/// by itself, a tap or a swipe moves on.
///
/// Rani approved two of them from the mockups in `reports/games`
/// (`kid-whatsnew2.html`, direction ב, and `parent-story.html`): the same
/// rhythm on both sides so Tofy reads as one app, with the copy pointed at a
/// different reader. The child's story shows the ACTION ("כָּל תְּשׁוּבָה נְכוֹנָה
/// פּוֹתַחַת רֶמֶז"); the parent's shows the BENEFIT, with a real example instead
/// of an explanation.
///
/// Two rules shaped this file:
///
/// 1. **Every new thing is SHOWN — five cards at most.** Rani: "בסטורי צריך
///    להציג את כל החידושים! כלומר אם יש 12 מסכים חדשים אז את כולם", and later:
///    "מקסימום 5 שקפים" — and then the rule that reconciles the two: "12 …
///    לא יכנסו, צריך להציג אותם כמה ביחד נגיד 4 בטאב אחד ואז יהיה 3 טאבים
///    שמדברים על המשחקים החדשים וישארו עוד 2 טאבים". So every game keeps its
///    own real screen, and `fit` packs them four to a card; what is left of
///    the five goes to the other news, by `priority`.
/// 2. **Content, not screens.** The next release is an edit to `byBuild`
///    below — a story carries an id, its art, a title, one line and the
///    audience it belongs to, and `WhatsNewStoryView` draws whatever it finds.
///
/// ⚠️ RELEASE CHECKLIST: add an entry to `byBuild` for the build you are about
/// to upload, next to the `WhatsNewContent.Release` for the same build. A build
/// with no entry shows no story, which is correct for a build that only changed
/// things nobody would notice.
enum WhatsNewStories {

    // MARK: - The content

    /// Keyed by the build that introduced these stories — the same key
    /// `WhatsNewContent.releases` uses, so the notes and the story can never
    /// drift onto different builds.
    /// Cached per language AND per gender: a child's story says "בָּא לְךָ" or
    /// "בָּא לָךְ", so a brother and a sister on one iPad must not share a cache
    /// entry the way two screens in one language can.
    static var byBuild: [Int: [StoryItem]] {
        LocalizedCache.value("whatsNewStories.byBuild." + (Gendered.isGirl ? "f" : "m")) { [195: build187] }
    }

    /// 🎮 Build 187 — the twelve mini-games, the chooser in front of them, the
    /// grade-matched content behind them, and the parent's "רק שאלות רגילות".
    ///
    /// Everything a parent reads here comes from `WhatsNewContent`'s note for
    /// the same build (`note(_:)`), and everything a child reads comes from the
    /// game's own `MiniGameKind` — so there is exactly one place to fix a line.
    private static var build187: [StoryItem] {
        var items: [StoryItem] = []

        // ── 1 · The chooser ────────────────────────────────────────────────
        // 👧 The child meets the screen they will actually see first.
        items.append(StoryItem(
            id: "187.chooser.kid",
            art: .emoji("🎮"),
            title: Gendered.g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")),
            line: tr("בּוֹחֲרִים עוֹלָם, וְאָז בּוֹחֲרִים: שְׁאֵלוֹת רְגִילוֹת אוֹ מִשְׂחָק"),
            audience: .child,
            priority: 3))

        // …and the chooser itself, drawn as the screen the child will meet:
        // "שאלות" on one side, a real game board on the other.
        items.append(StoryItem(
            id: "187.chooser.parent",
            art: .chooser(game: .pairs, topic: .math),
            kicker: tr("מסך חדש"),
            title: tr("איך בא לך לשחק?"),
            line: tr("בלחיצה אחת נכנסים ישר לשחק — או ישר לשאלות"),
            audience: .parent,
            priority: 1))

        // ── 2 · Every game, by its real screen ────────────────────────────
        // One entry per game, for BOTH readers; `fit` packs them four to a
        // card. A thirteenth game is a new `MiniGameKind` and nothing here.
        for kind in MiniGameKind.allCases {
            items.append(StoryItem(
                id: "187.game.\(kind.rawValue)",
                art: .game(kind, topic: previewTopic(kind)),
                title: kind.shortName,
                line: kind.blurb,
                audience: .both,
                seconds: 4.2,
                priority: 3))
        }

        // 🔒 THE thing this build fixed for parents: one place for what stays
        // open, and everything else locked — a new app included.
        items.append(StoryItem(
            id: "191.lock.parent",
            art: .rows([
                StoryRow(label: tr("פתוחות תמיד"), value: tr("טופי · טלפון")),
                StoryRow(label: tr("כל השאר"), value: tr("נעול")),
                StoryRow(label: tr("אפליקציה חדשה"), value: tr("נעולה גם היא")),
            ]),
            kicker: tr("נעילה"),
            title: tr("מה פתוח ומה נעול — במקום אחד"),
            line: tr("מהרגע שמאשרים זמן מסך בטלפון של הילד, הכל נעול חוץ מטופי עד שמרוויחים זמן — גם אפליקציה שיתקין מחר. בלי לבחור או לסמן כלום"),
            audience: .parent,
            seconds: 7,
            priority: 2))

        // ── 3 · Grade-matched content (parent: a real example) ────────────
        items.append(StoryItem(
            id: "187.gradefit.parent",
            art: .rows([
                StoryRow(label: tr("כיתה ג׳ · עברית"), value: tr("מכונית · אונייה")),
                StoryRow(label: tr("כיתה ו׳ · עברית"), value: tr("מיקרופון · גלגיליות")),
                StoryRow(label: tr("כיתה ו׳ · אנגלית"), value: "bicycle · teacher"),
            ]),
            kicker: tr("מותאם לגיל"),
            title: tr("כל משחק לפי הכיתה של הילד"),
            line: note("gradefit"),
            audience: .parent,
            seconds: 7,
            priority: 1))

        // 👶 …and the other end of that ladder: what גן actually gets. The
        // board here is the real text-free one, so a parent can see that
        // "a game for a five-year-old" is pictures, not small print.
        items.append(StoryItem(
            id: "187.prereader.parent",
            art: .preReaderGame(.balloon, topic: .math),
            kicker: tr("גן"),
            title: tr("חמישה משחקים בלי מילים"),
            line: tr("בגן המשחקים הם תמונות, צבעים וכמויות — וההוראה נאמרת בקול, לא נכתבת"),
            audience: .parent,
            seconds: 6.5,
            priority: 0))

        // 🔐 One game shown as what it really asks for: deduction.
        items.append(StoryItem(
            id: "187.vault.parent",
            art: .vault(code: ["3", "?", "?"], clues: [
                tr("הספרה הראשונה היא 3"),
                tr("הספרה השנייה גדולה מ־5"),
                tr("הספרה השלישית זוגית"),
            ]),
            kicker: tr("חשיבה"),
            title: tr("הכספת — משחק של הסקה"),
            line: tr("כל תשובה נכונה פותחת רמז, והרמזים ביחד מגלים את הקוד"),
            audience: .parent,
            seconds: 7,
            priority: 0))

        // ── 4 · Minutes are earned in a game too ─────────────────────────
        items.append(StoryItem(
            id: "187.minutes.kid",
            art: .emoji("⏱"),
            title: tr("גַּם בַּמִּשְׂחָקִים מַרְוִיחִים דַּקּוֹת"),
            line: tr("כָּל תְּשׁוּבָה נְכוֹנָה מוֹסִיפָה זְמַן מִשְׂחָק"),
            audience: .child,
            priority: 1))

        items.append(StoryItem(
            id: "187.minutes.parent",
            art: .rows([
                StoryRow(label: tr("שאלה רגילה"), value: tr("⏱ זמן מסך")),
                StoryRow(label: tr("תשובה נכונה במשחק"), value: tr("⏱ אותו זמן")),
                StoryRow(label: tr("סיבוב הפתעה ⚡"), value: tr("⭐💎 כפולים")),
            ]),
            kicker: tr("זמן מסך"),
            title: tr("גם במשחקים מרוויחים דקות"),
            line: note("minutes"),
            audience: .parent,
            seconds: 6.5,
            priority: 1))

        // ── 5 · The surprise round (child only — it is a surprise) ───────
        items.append(StoryItem(
            id: "187.surprise.kid",
            art: .emoji("⚡"),
            title: tr("סִבּוּב הַפְתָּעָה"),
            line: tr("כָּל כַּמָּה שְׁאֵלוֹת קוֹפֵץ מִשְׂחָק קָצָר — עִם כּוֹכָבִים וְיַהֲלוֹמִים כְּפוּלִים"),
            audience: .child,
            priority: 0))

        // ── 6 · "רק שאלות רגילות" — where it actually lives ──────────────
        items.append(StoryItem(
            id: "187.onlyQuestions.parent",
            art: .rows([
                StoryRow(label: tr("רק שאלות רגילות"), value: "", kind: .switchOn),
                StoryRow(label: tr("זמן מסך ליום"), value: tr("60 דקות")),
                StoryRow(label: tr("כיתה"), value: tr("ד׳")),
            ]),
            kicker: tr("בשליטה שלכם"),
            title: tr("רק שאלות רגילות"),
            line: note("onlyQuestions"),
            audience: .parent,
            seconds: 7,
            priority: 1))

        // ── 7 · The rest of the parent's own screens ────────────────────
        // ⏱ The daily ceiling, drawn as the picker it really is — including
        // the "אחר" that takes any number of minutes.
        items.append(StoryItem(
            id: "187.dailyCap.parent",
            art: .chips(DailyCapChoice.options.map(DailyCapChoice.label) + [tr("אחר")],
                        selected: DailyCapChoice.options.firstIndex(of: DailyCapChoice.defaultMinutes) ?? 1),
            kicker: tr("זמן מסך ליום"),
            title: tr("אתם קובעים כמה"),
            line: tr("חצי שעה, שעה, שעתיים, בלי הגבלה — או כל מספר דקות שתקלידו"),
            audience: .parent,
            seconds: 6.5,
            priority: 0))

        // 🧒 Kid Mode. Parents were writing in that they could not find it, so
        // the card shows the row the button really sits on.
        items.append(StoryItem(
            id: "187.kidMode.parent",
            art: .rows([
                StoryRow(label: tr("כרטיס הילד"), kind: .action(tr("תנו ל\(exampleChild) לשחק כאן 🧒"))),
                StoryRow(label: tr("יציאה ממצב ילד"), value: tr("מוגן בקוד הורים")),
            ]),
            kicker: tr("הטלפון שלכם"),
            title: tr("תנו ל\(exampleChild) לשחק כאן"),
            line: tr("מוסרים לילד את הטלפון שלכם לכמה דקות — והיציאה חזרה מוגנת בקוד"),
            audience: .parent,
            seconds: 6.5,
            priority: 2))

        // 📱 The iPad that was set up as a parent device by mistake.
        items.append(StoryItem(
            id: "187.ipadChild.parent",
            art: .rows([
                StoryRow(label: "iPhone", value: tr("מכשיר הורה")),
                StoryRow(label: "iPad", kind: .action(tr("להפוך למכשיר של ילד"))),
            ]),
            kicker: tr("מכשירים"),
            title: tr("האייפד הוא של הילד"),
            line: tr("אייפד שהוגדר בטעות כמכשיר הורה הופך למכשיר של ילד בלחיצה אחת, בלי למחוק כלום"),
            audience: .parent,
            seconds: 6.5,
            priority: 0))

        // 💬 And the way to reach us, as the conversation it opens.
        items.append(StoryItem(
            id: "187.chat.parent",
            art: .chat([
                StoryChatLine(text: tr("שלום! כאן צוות טופי 👋 איך אפשר לעזור?"), mine: false),
                StoryChatLine(text: tr("איך מחברים את האייפד לילדה שלי?"), mine: true),
            ]),
            kicker: tr("אנחנו כאן"),
            title: tr("צ'אט עם צוות טופי"),
            line: tr("הכפתור 💬 במסך הבית פותח שיחה איתנו — והתשובה מגיעה לטלפון שלכם"),
            audience: .parent,
            seconds: 6.5,
            priority: 1))

        // ── 8 · The closing story ────────────────────────────────────────
        // 🦊 The child's own buddy hands them a small ⭐/💎 for having watched,
        // and then it closes itself to the map. The only button in the whole
        // story sits here (Rani: "צריך כפתור למטה במסך האחרון") — it does
        // exactly what the ending does anyway, so nothing waits on it.
        items.append(StoryItem(
            id: "187.closing.kid",
            art: .gift(.childsBuddy, stars: Self.watchStars, diamonds: Self.watchDiamonds),
            title: tr("בּוֹאוּ נְשַׂחֵק! 🚀"),
            // The minutes card rarely survives the cut to five, so the
            // closing card says it too.
            line: tr("גַּם בַּמִּשְׂחָקִים מַרְוִיחִים דַּקּוֹת — וְהִנֵּה מַתָּנָה קְטַנָּה בִּשְׁבִילְכֶם"),
            audience: .child,
            seconds: 6,
            priority: 3))

        // 🦁 Tofy's own lion for the parent: where to find this again, and in.
        items.append(StoryItem(
            id: "187.closing.parent",
            art: .character(.lion),
            kicker: tr("זה הכל"),
            title: tr("נתראה בפנים 👋"),
            line: tr("אפשר לראות את זה שוב בכל רגע: הגדרות ← מה חדש"),
            audience: .parent,
            seconds: 6,
            priority: 0))

        return items
    }

    /// ⭐/💎 for watching to the end — the chips the mockup promises. Granted
    /// once, on the same build key that decides the story is over.
    static let watchStars = 10
    static let watchDiamonds = 15

    /// One line from the release notes for the same build. The notes are the
    /// single source: a story card never retypes a sentence a parent can also
    /// read in הגדרות ← מה חדש.
    private static func note(_ key: String) -> String {
        WhatsNewContent.item(key)?.line ?? ""
    }

    /// Which world a game's miniature should be drawn FROM, so the board the
    /// child sees in the story is the board they will play: letters for the
    /// word games, prices for the grocery, numbers for the rest.
    static func previewTopic(_ kind: MiniGameKind) -> Topic {
        switch kind {
        case .word, .wordSearch: return .hebrew
        case .sort, .lightning:  return .science
        case .grocery:           return .money
        default:                 return .math
        }
    }

    /// The name on the "תנו ל… לשחק כאן" card: the family's own first child,
    /// so the card shows the button exactly as this parent will find it.
    private static var exampleChild: String {
        // The parent side carries no niqqud, and a name typed on a child's
        // device may have some ("דָּנָה"). A name is safe to strip — unlike a
        // word, it has no plene spelling to lose.
        Question.stripNiqqud(ProfileStore.shared.profiles.first?.name ?? tr("דנה"))
    }

    // MARK: - Which stories, for whom

    /// ⚠️ A run is never longer than this. Rani, build 189: "סטוריז להורה וגם
    /// לילד שיהיה מקסימום 5 שקפים!" — nobody reaches the end of sixteen cards.
    /// It is enforced here, not by counting entries in `byBuild`, so a future
    /// release cannot ship a fifteen-card run by accident. Put the cards that
    /// matter first; the rest are cut.
    static let maxCards = 5

    /// Every story for an audience, oldest build first, for the builds this
    /// reader has not seen. One release is one story run.
    static func items(for audience: StoryAudience, unseenBuilds: [Int]) -> [StoryItem] {
        let table = byBuild
        return fit(unseenBuilds.sorted()
            .flatMap { table[$0] ?? [] }
            .filter { $0.audience.includes(audience) && offered($0) },
                   for: audience)
    }

    /// The current build's stories — what a demo screen and a re-open show.
    static func current(for audience: StoryAudience) -> [StoryItem] {
        let build = Int(AppInfo.build) ?? 0
        let table = byBuild
        // The newest entry at or below this build; a story is never shown on a
        // build that predates it.
        guard let newest = table.keys.filter({ $0 <= build }).max() ?? table.keys.max() else { return [] }
        return fit((table[newest] ?? [])
            .filter { $0.audience.includes(audience) && offered($0) },
                   for: audience)
    }

    /// 🧩 Everything new, in five cards at most — the smart part.
    ///
    /// 1. **Games are packed, never cut.** Every run of game cards becomes
    ///    cards of up to `perGrid` real screens each, balanced: twelve games
    ///    are 4 · 4 · 4, a גן child's five are 3 · 2. A lone game stays a
    ///    full-size card.
    /// 2. **Then the five are chosen by `priority`**, ties broken by story
    ///    order, and shown in story order. With twelve games that is the
    ///    three game cards plus the two highest-priority others; the rest of
    ///    the release still lives in הגדרות ← מה חדש.
    static func fit(_ list: [StoryItem], for audience: StoryAudience) -> [StoryItem] {
        var packed: [StoryItem] = []
        var run: [StoryItem] = []

        func flush() {
            defer { run.removeAll() }
            guard run.count > 1 else { packed.append(contentsOf: run); return }
            let cards = Int((Double(run.count) / Double(perGrid)).rounded(.up))
            var start = 0
            for c in 0..<cards {
                // Balanced: the first `run.count % cards` cards take one more.
                let size = run.count / cards + (c < run.count % cards ? 1 : 0)
                let slice = Array(run[start..<(start + size)])
                start += size
                packed.append(gridCard(slice, part: c + 1, of: cards,
                                       total: run.count, for: audience))
            }
        }
        for item in list {
            if case .game = item.art { run.append(item) } else { flush(); packed.append(item) }
        }
        flush()

        guard packed.count > maxCards else { return packed }
        let keep = Set(packed.indices.sorted {
            packed[$0].priority != packed[$1].priority
                ? packed[$0].priority > packed[$1].priority
                : $0 < $1
        }.prefix(maxCards))
        return packed.indices.filter(keep.contains).map { packed[$0] }
    }

    /// How many real game screens share one card — four still read as phones
    /// on the smallest iPhone.
    static let perGrid = 4

    private static func gridCard(_ games: [StoryItem], part: Int, of parts: Int,
                                 total: Int, for audience: StoryAudience) -> StoryItem {
        let kinds: [MiniGameKind] = games.compactMap {
            if case .game(let kind, _) = $0.art { return kind }
            return nil
        }
        let isKid = audience != .parent
        let names = kinds.map { isKid ? $0.shortName : $0.parentName }
        let title = isKid ? tr("מִשְׂחָקִים חֲדָשִׁים") : tr("\(total) משחקים חדשים")
        let line: String = {
            if isKid { return parts > 1 ? tr("חֵלֶק \(part) מִתּוֹךְ \(parts)") : "" }
            return parts > 1
                ? tr("חלק \(part) מתוך \(parts) · הילד בוחר: שאלות רגילות או משחק")
                : tr("הילד בוחר: שאלות רגילות או משחק")
        }()
        return StoryItem(
            id: "games.\(part).\(kinds.map(\.rawValue).joined(separator: "-"))",
            art: .gameGrid(kinds, names: names),
            kicker: isKid ? nil : tr("מה חדש"),
            title: title,
            line: line,
            audience: audience,
            // A pre-reader hears which games are on the card, not "part 2 of 3".
            spoken: "\(title). " + names.joined(separator: ", "),
            seconds: 6.5,
            priority: games.map(\.priority).max() ?? 3)
    }

    /// 👶 A גן child is shown the five games they will actually be dealt, and
    /// not the seven `MiniGameGradeFit` keeps shut for them.
    ///
    /// Rani's "אם יש 12 מסכים חדשים אז את כולם" means never fold twelve new
    /// things into one summary card — it does not mean advertise a game this
    /// child's app will never offer. Every other grade still sees all twelve;
    /// the chooser is what decides which of them a given WORLD carries.
    private static func offered(_ item: StoryItem) -> Bool {
        guard case .game(let kind, _) = item.art else { return true }
        let grade = ProfileStore.shared.active?.effectiveGrade ?? 1
        guard PreReaderGames.isPreReader(grade) else { return true }
        return MiniGameGradeFit.preReaderRoster.contains(kind)
    }

    // MARK: - 👨‍👩‍👧 Shown once, on the parent's device

    /// The parent story replaces the old "מה חדש" sheet on the dashboard, so it
    /// is decided by the very same stored build token — a parent can never be
    /// shown both, and an install that already saw build N is not caught up on
    /// it again. See `WhatsNewContent.shouldShow`.
    @MainActor
    static var parentShouldShow: Bool {
        guard WhatsNewContent.shouldShow else { return false }
        return !items(for: .parent, unseenBuilds: WhatsNewContent.unseenReleases.map(\.build)).isEmpty
    }

    /// What the parent is caught up on right now.
    @MainActor
    static var parentItems: [StoryItem] {
        let unseen = items(for: .parent, unseenBuilds: WhatsNewContent.unseenReleases.map(\.build))
        return unseen.isEmpty ? current(for: .parent) : unseen
    }

    @MainActor
    static func markParentShown() { WhatsNewContent.markShown() }

    // MARK: - 👧 Shown once, per child

    /// Per child, not per device: two siblings on one iPad each get their own
    /// tour. Same token shape as the parent's (`"2026.10.3 (186)"`), read for
    /// the build number inside it.
    private static func kidKey(_ id: UUID) -> String { "whatsNewStory.kid.\(id.uuidString)" }

    /// A child who has been in the family for less than a day is NEW, and a
    /// new child meets the games by playing them — not through a tour of what
    /// changed since a build they never had.
    private static let newChildWindow: TimeInterval = 24 * 60 * 60

    /// Only what this child has not seen — the question "is there a story".
    @MainActor
    private static func kidUnseenItems(for profile: Profile) -> [StoryItem] {
        items(for: .child, unseenBuilds: WhatsNewContent.unseenBuilds(seen: seenBuild(forKey: kidKey(profile.id))))
    }

    /// What to actually play. A child with no record at all (this build is the
    /// first with a story) gets this build's run rather than nothing.
    @MainActor
    static func kidItems(for profile: Profile) -> [StoryItem] {
        let unseen = kidUnseenItems(for: profile)
        return unseen.isEmpty ? current(for: .child) : unseen
    }

    /// Whether to open the story for this child now — and nothing else: the
    /// caller marks it shown, exactly like the September party does, so a
    /// force-quit mid-story cannot make it reappear forever.
    @MainActor
    static func kidShouldShow(for profile: Profile) -> Bool {
        let key = kidKey(profile.id)
        guard UserDefaults.standard.string(forKey: key) != nil else {
            // First sighting on this device. An existing child gets the tour of
            // what this update brought; a child created minutes ago does not —
            // they are about to meet the games by playing them.
            guard Date().timeIntervalSince(profile.createdAt) >= newChildWindow else {
                UserDefaults.standard.set(WhatsNewContent.seenToken, forKey: key)
                return false
            }
            return !current(for: .child).isEmpty
        }
        return !kidUnseenItems(for: profile).isEmpty
    }

    @MainActor
    static func markKidShown(for profile: Profile) {
        UserDefaults.standard.set(WhatsNewContent.seenToken, forKey: kidKey(profile.id))
    }

    /// The build inside a stored token, in any of the shapes the app has ever
    /// written (`"186"`, `"2026.10.3 (186)"`, a bare version).
    private static func seenBuild(forKey key: String) -> Int? {
        WhatsNewContent.build(inToken: UserDefaults.standard.string(forKey: key))
    }
}

// MARK: - The shape of a story

/// Who a story is for. A story written for both is written in the language of
/// whichever side is reading it — which in practice is almost never, because a
/// child reads niqqud and a parent does not.
enum StoryAudience: String {
    case child, parent, both

    func includes(_ reader: StoryAudience) -> Bool { self == .both || self == reader }
}

/// One row inside a story's example card: a label, and the real thing beside it.
struct StoryRow: Identifiable {
    let id = UUID()
    let label: String
    var value: String = ""
    var kind: Kind = .bullet

    enum Kind {
        /// A mint ● before the label — "here is an example".
        case bullet
        /// A real-looking switch, turned on — "here is where it lives".
        case switchOn
        /// The gold button that really sits on that row, drawn not live —
        /// "תנו לשחק כאן", "להפוך למכשיר של ילד".
        case action(String)
    }
}

/// One line in the support-chat preview.
struct StoryChatLine: Identifiable {
    let id = UUID()
    let text: String
    /// True for the parent's own message (trailing, gold); false for צוות טופי.
    let mine: Bool
}

/// Which of Tofy's own characters a story shows. Rani, on seeing the system
/// 🦁 on the closing card: "מה זה האריה הזה? אמור להיות שלנו..." — so a
/// character is named here and drawn from `Character3DCatalog`, never typed as
/// an emoji.
enum StoryCharacter {
    /// 🦊 The child's OWN buddy — the one they chose (or were given) in the
    /// shop. Falls back to the catalog's default when there is none.
    case childsBuddy
    /// 🦁 Tofy's lion, which is who speaks to a parent.
    case lion
}

/// What fills the middle of a story. Everything else about a story is text, so
/// this is the only place a new KIND of card has to be taught.
enum StoryArt {
    /// One huge emoji, glowing. For an idea (⏱ ⚡ 🎮) — never for a character,
    /// which has real art.
    case emoji(String)
    /// One of Tofy's own characters, drawn from its artwork.
    case character(StoryCharacter)
    /// 🎮 A real mini-game: its own emoji huge, and under it the real board,
    /// drawn by `MiniGamePreview` (including the גן form for a pre-reader).
    case game(MiniGameKind, topic: Topic)
    /// 🎮🎮 Up to four real games on one card, each in its own phone with its
    /// name under it — what `WhatsNewStories.fit` packs a run of games into.
    case gameGrid([MiniGameKind], names: [String])
    /// 👶 The same, forced to the pre-reader board — so a PARENT can see the
    /// text-free גן form their five-year-old actually gets.
    case preReaderGame(MiniGameKind, topic: Topic)
    /// 🕹 The chooser screen in miniature: "שאלות" beside a real game board,
    /// which is the choice the child is handed after picking a world.
    case chooser(game: MiniGameKind, topic: Topic)
    /// Every emoji at once, as a grid — "all twelve", for the parent.
    case tiles([String])
    /// Example rows — a real example instead of an explanation.
    case rows([StoryRow])
    /// 🔐 The vault: the code slots with one digit known, and the clues open
    /// so far. The point of the game in one picture.
    case vault(code: [String], clues: [String])
    /// A row of choices with one picked — the daily screen-time picker.
    case chips([String], selected: Int)
    /// 💬 A real-looking exchange with צוות טופי.
    case chat([StoryChatLine])
    /// ⭐/💎 the child just earned, under their own buddy.
    case gift(StoryCharacter, stars: Int, diamonds: Int)
}

/// One screen of the story.
struct StoryItem: Identifiable {
    /// Stable, build-prefixed (`"187.game.vault"`) — so a story can be named
    /// in a bug report and found.
    let id: String
    let art: StoryArt
    /// The small gold line above the title. The parent's mockup has one on
    /// every card; the child's has none (a child reads the title, not a label).
    var kicker: String? = nil
    let title: String
    let line: String
    var audience: StoryAudience = .both
    /// What 🔊 reads out. Defaults to the title and the line, which is what a
    /// child needs read to them.
    var spoken: String? = nil
    /// How long before it moves on by itself.
    var seconds: Double = 5.0
    /// Which cards survive the cut to `WhatsNewStories.maxCards`: higher
    /// first, story order breaking ties. 3 = the heart of the release.
    var priority: Int = 1

    var spokenText: String { spoken ?? "\(title). \(line)" }
}
