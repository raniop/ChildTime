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
/// 1. **Every new thing gets its own story.** Rani: "בסטורי צריך להציג את כל
///    החידושים! כלומר אם יש 12 מסכים חדשים אז את כולם" — twelve new games are
///    twelve stories on the child's side, never one summary card.
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
        LocalizedCache.value("whatsNewStories.byBuild." + (Gendered.isGirl ? "f" : "m")) { [186: build186] }
    }

    /// 🎮 Build 186 — the twelve mini-games, the chooser in front of them, the
    /// grade-matched content behind them, and the parent's "רק שאלות רגילות".
    ///
    /// Everything a parent reads here comes from `WhatsNewContent`'s note for
    /// the same build (`note(_:)`), and everything a child reads comes from the
    /// game's own `MiniGameKind` — so there is exactly one place to fix a line.
    private static var build186: [StoryItem] {
        var items: [StoryItem] = []

        // ── 1 · The chooser ────────────────────────────────────────────────
        // 👧 The child meets the screen they will actually see first.
        items.append(StoryItem(
            id: "186.chooser.kid",
            art: .emoji("🎮"),
            title: Gendered.g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")),
            line: tr("בּוֹחֲרִים עוֹלָם, וְאָז בּוֹחֲרִים: שְׁאֵלוֹת רְגִילוֹת אוֹ מִשְׂחָק"),
            audience: .child))

        // 👨‍👩‍👧 …and the parent meets all twelve at once, with what it means.
        items.append(StoryItem(
            id: "186.games.parent",
            art: .tiles(MiniGameKind.allCases.map(\.emoji)),
            kicker: tr("מה חדש"),
            title: tr("12 משחקים חדשים"),
            line: tr("הילד בוחר איך לענות: שאלות רגילות או משחק — והתוכן נשאר אותו תוכן"),
            audience: .parent,
            seconds: 6.5))

        // ── 2 · One story per game ────────────────────────────────────────
        // Rani: all twelve, never a summary. Title, line and art are the
        // game's own, so a thirteenth game is a new `MiniGameKind` and
        // nothing here.
        for kind in MiniGameKind.allCases {
            items.append(StoryItem(
                id: "186.game.\(kind.rawValue)",
                art: .game(kind, topic: previewTopic(kind)),
                title: kind.title,
                line: kind.blurb,
                audience: .child,
                seconds: 4.2))
        }

        // ── 3 · Grade-matched content (parent: a real example) ────────────
        items.append(StoryItem(
            id: "186.gradefit.parent",
            art: .rows([
                StoryRow(label: tr("כיתה ג׳ · עברית"), value: tr("מכונית · אונייה")),
                StoryRow(label: tr("כיתה ו׳ · עברית"), value: tr("מיקרופון · גלגיליות")),
                StoryRow(label: tr("כיתה ו׳ · אנגלית"), value: "bicycle · teacher"),
            ]),
            kicker: tr("מותאם לגיל"),
            title: tr("כל משחק לפי הכיתה של הילד"),
            line: note("gradefit"),
            audience: .parent,
            seconds: 7))

        // ── 4 · Minutes are earned in a game too ─────────────────────────
        items.append(StoryItem(
            id: "186.minutes.kid",
            art: .emoji("⏱"),
            title: tr("גַּם בַּמִּשְׂחָקִים מַרְוִיחִים דַּקּוֹת"),
            line: tr("כָּל תְּשׁוּבָה נְכוֹנָה מוֹסִיפָה זְמַן מִשְׂחָק"),
            audience: .child))

        items.append(StoryItem(
            id: "186.minutes.parent",
            art: .rows([
                StoryRow(label: tr("שאלה רגילה"), value: tr("⏱ זמן מסך")),
                StoryRow(label: tr("תשובה נכונה במשחק"), value: tr("⏱ אותו זמן")),
                StoryRow(label: tr("סיבוב הפתעה ⚡"), value: tr("⭐💎 כפולים")),
            ]),
            kicker: tr("זמן מסך"),
            title: tr("גם במשחקים מרוויחים דקות"),
            line: note("minutes"),
            audience: .parent,
            seconds: 6.5))

        // ── 5 · The surprise round (child only — it is a surprise) ───────
        items.append(StoryItem(
            id: "186.surprise.kid",
            art: .emoji("⚡"),
            title: tr("סִבּוּב הַפְתָּעָה"),
            line: tr("כָּל כַּמָּה שְׁאֵלוֹת קוֹפֵץ מִשְׂחָק קָצָר — עִם כּוֹכָבִים וְיַהֲלוֹמִים כְּפוּלִים"),
            audience: .child))

        // ── 6 · "רק שאלות רגילות" — where it actually lives ──────────────
        items.append(StoryItem(
            id: "186.onlyQuestions.parent",
            art: .rows([
                StoryRow(label: tr("רק שאלות רגילות"), value: "", kind: .switchOn),
                StoryRow(label: tr("זמן מסך ליום"), value: tr("60 דקות")),
                StoryRow(label: tr("כיתה"), value: tr("ד׳")),
            ]),
            kicker: tr("בשליטה שלכם"),
            title: tr("רק שאלות רגילות"),
            line: note("onlyQuestions"),
            audience: .parent,
            seconds: 7))

        // ── 7 · The closing story ────────────────────────────────────────
        // 🦊 The child's own buddy hands them a small ⭐/💎 for having watched,
        // and then it closes itself to the map. The only button in the whole
        // story sits here (Rani: "צריך כפתור למטה במסך האחרון") — it does
        // exactly what the ending does anyway, so nothing waits on it.
        items.append(StoryItem(
            id: "186.closing.kid",
            art: .gift(.childsBuddy, stars: Self.watchStars, diamonds: Self.watchDiamonds),
            title: tr("בּוֹאוּ נְשַׂחֵק! 🚀"),
            line: tr("וְהִנֵּה מַתָּנָה קְטַנָּה בִּשְׁבִילְכֶם"),
            audience: .child,
            seconds: 6))

        // 🦁 Tofy's own lion for the parent: where to find this again, and in.
        items.append(StoryItem(
            id: "186.closing.parent",
            art: .character(.lion),
            kicker: tr("זה הכל"),
            title: tr("נתראה בפנים 👋"),
            line: tr("אפשר לראות את זה שוב בכל רגע: הגדרות ← מה חדש"),
            audience: .parent,
            seconds: 6))

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
    private static func previewTopic(_ kind: MiniGameKind) -> Topic {
        switch kind {
        case .word, .wordSearch: return .hebrew
        case .sort, .lightning:  return .science
        case .grocery:           return .money
        default:                 return .math
        }
    }

    // MARK: - Which stories, for whom

    /// Every story for an audience, oldest build first, for the builds this
    /// reader has not seen. One release is one story run.
    static func items(for audience: StoryAudience, unseenBuilds: [Int]) -> [StoryItem] {
        let table = byBuild
        return unseenBuilds.sorted()
            .flatMap { table[$0] ?? [] }
            .filter { $0.audience.includes(audience) }
    }

    /// The current build's stories — what a demo screen and a re-open show.
    static func current(for audience: StoryAudience) -> [StoryItem] {
        let build = Int(AppInfo.build) ?? 0
        let table = byBuild
        // The newest entry at or below this build; a story is never shown on a
        // build that predates it.
        guard let newest = table.keys.filter({ $0 <= build }).max() ?? table.keys.max() else { return [] }
        return (table[newest] ?? []).filter { $0.audience.includes(audience) }
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
    }
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
    /// Every emoji at once, as a grid — "all twelve", for the parent.
    case tiles([String])
    /// Example rows — a real example instead of an explanation.
    case rows([StoryRow])
    /// ⭐/💎 the child just earned, under their own buddy.
    case gift(StoryCharacter, stars: Int, diamonds: Int)
}

/// One screen of the story.
struct StoryItem: Identifiable {
    /// Stable, build-prefixed (`"186.game.vault"`) — so a story can be named
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

    var spokenText: String { spoken ?? "\(title). \(line)" }
}
