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

    var accuracyToday: Int { answeredToday > 0 ? Int((Double(correctToday) / Double(answeredToday)) * 100) : 0 }
    var goalProgress: Double { goalToday > 0 ? min(1, Double(answeredToday) / Double(goalToday)) : 0 }

    static let sample = KidSnapshot(name: "דָּן", stars: 4823, diamonds: 302, dayStreak: 5, answeredToday: 7, correctToday: 5, goalToday: 10)

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
    var id: String { name }

    static let sample: [FamilyChildSnapshot] = [
        .init(name: "דָּן", stars: 4823, dayStreak: 5, answeredToday: 61, accuracy: 73, playedToday: true),
        .init(name: "שִׁפִי", stars: 1290, dayStreak: 3, answeredToday: 18, accuracy: 81, playedToday: true),
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

struct KidEntry: TimelineEntry { let date: Date; let kid: KidSnapshot }

struct KidProvider: TimelineProvider {
    func placeholder(in context: Context) -> KidEntry { KidEntry(date: Date(), kid: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (KidEntry) -> Void) {
        completion(KidEntry(date: Date(), kid: context.isPreview ? .sample : KidSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<KidEntry>) -> Void) {
        let entry = KidEntry(date: Date(), kid: KidSnapshot.load())
        // Refresh hourly as a backstop; the app also reloads on data change.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct KidWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let kid: KidSnapshot
    var body: some View {
        Group {
            if family == .systemSmall { small } else { medium }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tofyBackground()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("🦁").font(.system(size: 20))
                Text(kid.name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Spacer()
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("⭐").font(.system(size: 22))
                Text("\(kid.stars)").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            }
            HStack(spacing: 6) {
                Pill(icon: "🔥", value: "\(kid.dayStreak)")
                Pill(icon: "💎", value: "\(kid.diamonds)")
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("🦁").font(.system(size: 26))
                    Text(kid.name).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text("⭐").font(.system(size: 20))
                    Text("\(kid.stars)").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Pill(icon: "🔥", value: "\(kid.dayStreak)")
                    Pill(icon: "💎", value: "\(kid.diamonds)")
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(.white.opacity(0.22), lineWidth: 9)
                    Circle().trim(from: 0, to: kid.goalProgress)
                        .stroke(Color(red: 1, green: 0.85, blue: 0.3), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(kid.answeredToday)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text("/\(kid.goalToday)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 78, height: 78)
                Text(kid.answeredToday >= kid.goalToday ? "כל הכבוד! 🎉" : "שאלות היום")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
            }
        }
        .padding(16)
    }
}

struct TofyKidWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TofyKidWidget", provider: KidProvider()) { entry in
            KidWidgetView(kid: entry.kid)
        }
        .configurationDisplayName("טופי שלי")
        .description("הכוכבים, הרצף וההתקדמות של היום.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
                    Circle().fill(kid.playedToday ? Color(red: 0.2, green: 0.86, blue: 0.6) : .white.opacity(0.25)).frame(width: 8, height: 8)
                    Text(kid.name).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 4)
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
        .description("סיכום יומי לכל ילד — כוכבים, רצף ושאלות.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
