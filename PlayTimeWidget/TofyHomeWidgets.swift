import WidgetKit
import SwiftUI

// MARK: - Shared App-Group data contract
// These models mirror `WidgetBridge` in the APP target. The app writes the JSON,
// the widget reads it — no Firestore, no auth needed inside the extension.

private enum WidgetStore {
    static let suite = "group.com.childtime.shared"
    static var defaults: UserDefaults { UserDefaults(suiteName: suite) ?? .standard }
    static let kidKey = "widget.kid.v1"
    static let familyKey = "widget.family.v1"
}

struct KidSnapshot: Codable {
    var name = "טופי"
    var stars = 0
    var diamonds = 0
    var dayStreak = 0
    var answeredToday = 0
    var correctToday = 0
    var goalToday = 10
    var playMinutes = 0
    /// 🧹/💰 — optional so JSON written by older app builds still decodes.
    var choresAvailable: Int? = nil
    var money: Int? = nil

    var accuracyToday: Int { answeredToday > 0 ? Int((Double(correctToday) / Double(answeredToday)) * 100) : 0 }

    static let sample = KidSnapshot(name: "דָּן", stars: 4823, diamonds: 302, dayStreak: 5, answeredToday: 7, correctToday: 5, goalToday: 10, playMinutes: 42, choresAvailable: 3, money: 12)

    static func load() -> KidSnapshot {
        guard let d = WidgetStore.defaults.data(forKey: WidgetStore.kidKey),
              let v = try? JSONDecoder().decode(KidSnapshot.self, from: d) else { return KidSnapshot() }
        return v
    }
}

struct FamilyChildSnapshot: Codable, Identifiable {
    var name: String
    var stars: Int
    var dayStreak: Int
    var answeredToday: Int
    var accuracy: Int
    var playedToday: Bool
    /// Newer fields — optional so JSON from older app builds still decodes.
    var playingNow: Bool? = nil
    var pendingChores: Int? = nil
    var money: Int? = nil
    var id: String { name }

    static let sample: [FamilyChildSnapshot] = [
        .init(name: "דָּן", stars: 4823, dayStreak: 5, answeredToday: 61, accuracy: 73, playedToday: true, playingNow: true, pendingChores: 1, money: 7),
        .init(name: "שִׁפִי", stars: 1290, dayStreak: 3, answeredToday: 18, accuracy: 81, playedToday: true, pendingChores: 0, money: 12),
        .init(name: "אוּרִי", stars: 940, dayStreak: 0, answeredToday: 0, accuracy: 0, playedToday: false),
    ]

    static func load() -> [FamilyChildSnapshot] {
        guard let d = WidgetStore.defaults.data(forKey: WidgetStore.familyKey),
              let v = try? JSONDecoder().decode([FamilyChildSnapshot].self, from: d) else { return [] }
        return v
    }
}

// MARK: - Shared look

private let tofyGradient = LinearGradient(
    colors: [Color(red: 0.42, green: 0.36, blue: 0.92), Color(red: 0.30, green: 0.66, blue: 0.95)],
    startPoint: .topLeading, endPoint: .bottomTrailing)

private extension View {
    /// iOS 17 widgets must paint via containerBackground; fall back for iOS 16.
    @ViewBuilder func tofyBackground() -> some View {
        if #available(iOS 17.0, *) { containerBackground(for: .widget) { tofyGradient } }
        else { background(tofyGradient) }
    }
    /// Accessory (lock-screen) widgets get the system's vibrant treatment —
    /// just satisfy the container-background requirement with clear.
    @ViewBuilder func lockScreenBackground() -> some View {
        if #available(iOS 17.0, *) { containerBackground(for: .widget) { Color.clear } }
        else { self }
    }
}

private struct Pill: View {
    let icon: String, value: String
    var body: some View {
        HStack(spacing: 3) {
            Text(icon)
            Text(value).font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.white.opacity(0.16), in: Capsule())
    }
}

// MARK: - KID widget

struct KidEntry: TimelineEntry { let date: Date; let kid: KidSnapshot; let avatar: UIImage? }

/// The child's real avatar — a small PNG of their chosen character that the app
/// renders into the App Group. nil → the widget shows the 🦁 fallback.
enum KidAvatar {
    static func load() -> UIImage? {
        guard let d = WidgetStore.defaults.data(forKey: "widget.kid.avatar") else { return nil }
        return UIImage(data: d)
    }
}

struct KidProvider: TimelineProvider {
    func placeholder(in context: Context) -> KidEntry { KidEntry(date: Date(), kid: .sample, avatar: nil) }
    func getSnapshot(in context: Context, completion: @escaping (KidEntry) -> Void) {
        let preview = context.isPreview
        completion(KidEntry(date: Date(), kid: preview ? .sample : KidSnapshot.load(), avatar: preview ? nil : KidAvatar.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<KidEntry>) -> Void) {
        let entry = KidEntry(date: Date(), kid: KidSnapshot.load(), avatar: KidAvatar.load())
        // Refresh hourly as a backstop; the app also reloads on data change.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct KidWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let kid: KidSnapshot
    var avatar: UIImage? = nil

    /// The child's chosen character, or 🦁 if none/3D-only.
    private func avatarView(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.18))
            if let avatar {
                Image(uiImage: avatar).resizable().scaledToFit().padding(size * 0.1)
            } else {
                Text("🦁").font(.system(size: size * 0.62))
            }
        }
        .frame(width: size, height: size)
    }

    // The three things a kid actually cares about — each gets its own tint.
    private let mint = Color(red: 0.30, green: 0.86, blue: 0.60)   // play minutes
    private let cyan = Color(red: 0.37, green: 0.76, blue: 0.97)   // diamonds
    private let gold = Color(red: 1.00, green: 0.82, blue: 0.30)   // stars

    var body: some View {
        switch family {
        case .accessoryCircular: accessoryCircle
        case .accessoryRectangular: accessoryRect
        case .systemSmall:
            small.environment(\.layoutDirection, .rightToLeft).tofyBackground()
        default:
            medium.environment(\.layoutDirection, .rightToLeft).tofyBackground()
        }
    }

    // Lock-screen circle: the number the kid cares about — minutes to play.
    private var accessoryCircle: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("🎮").font(.system(size: 13))
                Text("\(kid.playMinutes)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
        }
        .lockScreenBackground()
    }

    // Lock-screen row: minutes + streak + chores at a glance.
    private var accessoryRect: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(kid.name)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text("🎮 \(kid.playMinutes) דַּק׳ · 🔥 \(kid.dayStreak)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            if let chores = kid.choresAvailable, chores > 0 {
                Text("🧹 \(chores) מַטְלוֹת מְחַכּוֹת")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .environment(\.layoutDirection, .rightToLeft)
        .lockScreenBackground()
    }

    private var header: some View {
        HStack(spacing: 7) {
            avatarView(size: 30)
            Text(kid.name).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 4)
            if kid.dayStreak > 0 { Pill(icon: "🔥", value: "\(kid.dayStreak)") }
        }
    }

    private var medium: some View {
        VStack(spacing: 8) {
            header
            HStack(spacing: 9) {
                rewardTile("⏱️", "\(kid.playMinutes)", "דַּקּוֹת לְשַׂחֵק", mint)
                rewardTile("💎", kid.diamonds.formatted(), "יַהֲלוֹמִים", cyan)
                rewardTile("⭐", kid.stars.formatted(), "כּוֹכָבִים", gold)
            }
            // 🧹/💰 — the chores world at a glance (only when there's something).
            HStack(spacing: 8) {
                if let chores = kid.choresAvailable, chores > 0 {
                    Pill(icon: "🧹", value: "\(chores) מַטְלוֹת")
                }
                if let money = kid.money, money > 0 {
                    Pill(icon: "💰", value: "₪\(money)")
                }
                Spacer(minLength: 0)
                Pill(icon: "✅", value: "\(min(kid.correctToday, kid.goalToday))/\(kid.goalToday)")
            }
            Spacer(minLength: 0)
        }
        .padding(13)
    }

    // Small: play minutes is the hero (what the kid wants most); ⭐/💎 below.
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                avatarView(size: 26)
                Text(kid.name).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("⏱️").font(.system(size: 20))
                Text("\(kid.playMinutes)").font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
            }
            Text("דַּקּוֹת לְשַׂחֵק").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Text("💎 \(kid.diamonds.formatted())")
                Text("⭐ \(kid.stars.formatted())")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(14)
    }

    private func rewardTile(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 22))
            Text(value).font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.45).lineLimit(1)
            Text(label).font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78)).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.5), lineWidth: 1))
    }
}

struct TofyKidWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TofyKidWidget", provider: KidProvider()) { entry in
            KidWidgetView(kid: entry.kid, avatar: entry.avatar)
        }
        .configurationDisplayName("טופי שלי")
        .description("דקות המשחק, היהלומים, הכוכבים והמטלות שלך.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - KID HERO widget — big avatar on the right, stats stacked on the left

struct KidHeroView: View {
    let kid: KidSnapshot
    var avatar: UIImage? = nil

    private let mint = Color(red: 0.30, green: 0.86, blue: 0.60)
    private let cyan = Color(red: 0.37, green: 0.76, blue: 0.97)
    private let gold = Color(red: 1.00, green: 0.82, blue: 0.30)

    var body: some View {
        HStack(spacing: 12) {
            bigAvatar
            VStack(alignment: .leading, spacing: 9) {
                Text(kid.name).font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                statRow("⏱️", "\(kid.playMinutes)", "דַּקּוֹת לְשַׂחֵק", mint)
                statRow("💎", kid.diamonds.formatted(), "יַהֲלוֹמִים", cyan)
                statRow("⭐", kid.stars.formatted(), "כּוֹכָבִים", gold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
        .tofyBackground()
    }

    private var bigAvatar: some View {
        ZStack {
            Circle().fill(.white.opacity(0.16))
            if let avatar {
                Image(uiImage: avatar).resizable().scaledToFit().padding(11)
            } else {
                Text("🦁").font(.system(size: 62))
            }
        }
        .frame(width: 110, height: 110)
        .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
    }

    private func statRow(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 7) {
            Text(icon).font(.system(size: 18))
            Text(value).font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.55).lineLimit(1)
            Text(label).font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }
}

struct TofyKidHeroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TofyKidHeroWidget", provider: KidProvider()) { entry in
            KidHeroView(kid: entry.kid, avatar: entry.avatar)
        }
        .configurationDisplayName("טופי — הדמות שלי")
        .description("הדמות שלך בגדול, עם דקות, יהלומים וכוכבים.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - FAMILY widget (parent)

struct FamilyEntry: TimelineEntry { let date: Date; let kids: [FamilyChildSnapshot] }

struct FamilyProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyEntry { FamilyEntry(date: Date(), kids: FamilyChildSnapshot.sample) }
    func getSnapshot(in context: Context, completion: @escaping (FamilyEntry) -> Void) {
        completion(FamilyEntry(date: Date(), kids: context.isPreview ? FamilyChildSnapshot.sample : FamilyChildSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FamilyEntry>) -> Void) {
        let entry = FamilyEntry(date: Date(), kids: FamilyChildSnapshot.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct FamilyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let kids: [FamilyChildSnapshot]
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                familyAccessoryRect
            case .accessoryCircular:
                familyAccessoryCircle
            default:
                Group {
                    if kids.isEmpty { empty }
                    else {
                        switch family {
                        case .systemSmall: small
                        case .systemLarge: large
                        default: medium
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
                .tofyBackground()
            }
        }
    }

    /// Lock-screen circle: 🧹 chores waiting for the parent's approval.
    private var familyAccessoryCircle: some View {
        let pending = kids.reduce(0) { $0 + ($1.pendingChores ?? 0) }
        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("🧹").font(.system(size: 13))
                Text("\(pending)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
        }
        .lockScreenBackground()
    }

    /// Lock-screen row: who's playing right now + what waits for approval.
    private var familyAccessoryRect: some View {
        let playing = kids.filter { $0.playingNow ?? false }.map(\.name)
        let pending = kids.reduce(0) { $0 + ($1.pendingChores ?? 0) }
        return VStack(alignment: .trailing, spacing: 1) {
            Text("טופי · המשפחה")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(playing.isEmpty ? "אף אחד לא משחק כרגע"
                                 : "🟢 \(playing.joined(separator: ", ")) עכשיו")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(pending > 0 ? "🧹 \(pending) מטלות מחכות לאישור" : "🧹 אין מטלות ממתינות")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .environment(\.layoutDirection, .rightToLeft)
        .lockScreenBackground()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("👨‍👩‍👧").font(.system(size: 15))
            Text("המשפחה").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Spacer()
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("👨‍👩‍👧").font(.system(size: 34))
            Text("פתחו את טופי כדי לראות\nאת המשפחה כאן").font(.system(size: 12, weight: .semibold, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9))
        }.padding(14)
    }

    private var small: some View {
        let playedCount = kids.filter(\.playedToday).count
        let top = kids.max(by: { $0.dayStreak < $1.dayStreak })
        return VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            if let top {
                Text("הכי בוער 🔥").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                Text(top.name).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Text("רצף \(top.dayStreak) ימים").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Text("\(playedCount) מתוך \(kids.count) שיחקו היום").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }.padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            ForEach(kids.prefix(4)) { kid in
                HStack(spacing: 8) {
                    // 🟢 solid = playing RIGHT NOW; dim ring = played today.
                    Circle()
                        .fill((kid.playingNow ?? false) ? Color(red: 0.2, green: 0.86, blue: 0.6)
                              : kid.playedToday ? Color(red: 0.2, green: 0.86, blue: 0.6).opacity(0.4)
                              : .white.opacity(0.25))
                        .frame(width: 8, height: 8)
                    Text(kid.name).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 4)
                    if let n = kid.pendingChores, n > 0 {
                        Text("🧹\(n)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    if let m = kid.money, m > 0 {
                        Text("💰\(m)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    Text("⭐\(kid.stars)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.95))
                    Text("🔥\(kid.dayStreak)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.95))
                    Text("\(kid.answeredToday) ש'").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }.padding(14)
    }

    private var large: some View {
        let playedCount = kids.filter(\.playedToday).count
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("👨‍👩‍👧").font(.system(size: 18))
                Text("מבט על המשפחה").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("\(playedCount)/\(kids.count) שיחקו היום")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.16), in: Capsule())
            }
            ForEach(kids.prefix(6)) { kid in
                VStack(spacing: 5) {
                    HStack(spacing: 8) {
                        Circle().fill(kid.playedToday ? Color(red: 0.2, green: 0.86, blue: 0.6) : .white.opacity(0.25)).frame(width: 9, height: 9)
                        Text(kid.name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("⭐\(kid.stars)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.95))
                        Text("🔥\(kid.dayStreak)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.95))
                    }
                    HStack(spacing: 8) {
                        if let n = kid.pendingChores, n > 0 {
                            Text("🧹\(n)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        if let m = kid.money, m > 0 {
                            Text("💰₪\(m)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        Text("\(kid.answeredToday) שאלות").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.18)).frame(height: 6)
                                Capsule().fill(Color(red: 1, green: 0.85, blue: 0.3))
                                    .frame(width: geo.size.width * CGFloat(max(0, min(100, kid.accuracy))) / 100, height: 6)
                            }
                        }.frame(height: 6)
                        Text(kid.playedToday ? "\(kid.accuracy)%" : "—").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white).frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
                if kid.id != kids.prefix(6).last?.id {
                    Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                }
            }
            Spacer(minLength: 0)
        }.padding(16)
    }
}

struct TofyFamilyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TofyFamilyWidget", provider: FamilyProvider()) { entry in
            FamilyWidgetView(kids: entry.kids)
        }
        .configurationDisplayName("מבט על המשפחה")
        .description("מי משחק עכשיו, מטלות ממתינות, קופה — וכל הסטטים.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}
