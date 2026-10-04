import SwiftUI

/// 🔔 The parent's activity centre — everything that happened lately around the
/// family's children, grouped by day, newest first.
///
/// It is the only place a push the app sent survives after the banner is swiped
/// away: `ActivityFeedStore` merges what this device saw (`ActivityLog`), what
/// the server recorded when it pushed (`households/{hid}/activity`) and what the
/// dashboard's own stores already know (chores waiting, devices, today's
/// minutes). All first-party, all shown only to the family it belongs to.
struct ActivityCenterView: View {
    @StateObject private var feed = ActivityFeedStore.shared
    @EnvironmentObject private var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    /// Where a tapped row should take the parent. The dashboard owns the actual
    /// navigation, so the sheet can close first and the destination open after.
    var onOpen: (ActivityRoute, Profile?) -> Void = { _, _ in }

    private var days: [ActivityDay] { ActivityDay.group(feed.items) }

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(GlassBackdrop().ignoresSafeArea())
            .navigationTitle(tr("עדכונים"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("סיום")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .environment(\.colorScheme, .dark)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            // Freeze what was unread BEFORE clearing the badge, so the dots stay
            // visible while the parent is still reading the list.
            if readMark == nil { readMark = feed.readMark }
            feed.markRead()
        }
    }

    // MARK: Rows

    private var list: some View {
        List {
            ForEach(days) { day in
                Section {
                    ForEach(day.items) { item in
                        Button { open(item) } label: { row(item) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text(day.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                .glassRows()
            }
            Section {
                Text(tr("מוצגים כאן העדכונים מהשבועיים האחרונים. הם נשארים בתוך המשפחה שלכם בלבד."))
                    .font(.system(size: 12))
                    .foregroundStyle(GlassInk.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .rowSpacingCompat(8)
    }

    private func row(_ item: ActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(item)
            VStack(alignment: .leading, spacing: 3) {
                if let name = childName(item), !name.isEmpty {
                    Text(name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                Text(Self.time.string(from: item.at))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.tertiary)
                if item.at > (readMark ?? .distantPast) {
                    Circle().fill(GlassInk.good).frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
        .environment(\.layoutDirection, .app)
        .contentShape(Rectangle())
    }

    /// The child's own portrait when the row is about a child, otherwise the
    /// kind's emoji on a glass disc.
    @ViewBuilder private func avatar(_ item: ActivityItem) -> some View {
        if let profile = profile(for: item) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarView(profile: profile, size: 40)
                Text(item.kind.emoji)
                    .font(.system(size: 13))
                    .padding(3)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .offset(x: 4, y: 4)
            }
            .frame(width: 44, height: 44)
        } else {
            Text(item.kind.emoji)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.26), lineWidth: 1))
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🔔").font(.system(size: 54))
            Text(tr("אין עדכונים חדשים"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.primary)
            Text(tr("כאן יופיע כל מה שקורה אצל הילדים: כל התראה ששלחנו לכם, סבב שהסתיים ודקות שהורווחו, מטלה שמחכה לאישור שלכם, דקות מתנה ונעילה מרחוק, הישגים כמו רצף ועליית רמה, מכשיר שהצטרף למשפחה, ותשובה מצוות טופי."))
                .font(.system(size: 14))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Plumbing

    /// Captured once per appearance: `markRead()` clears the badge immediately,
    /// but the dots that show what was new should stay visible while the parent
    /// is still reading the list.
    @State private var readMark: Date?

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f
    }()

    private func profile(for item: ActivityItem) -> Profile? {
        guard let raw = item.childID, let id = UUID(uuidString: raw) else { return nil }
        return profiles.profiles.first { $0.id == id }
    }

    private func childName(_ item: ActivityItem) -> String? {
        profile(for: item)?.name ?? item.childName
    }

    private func open(_ item: ActivityItem) {
        Haptic.light()
        let route = item.kind.destination
        let who = profile(for: item)
        // A row about nobody in particular has nowhere better to go than here.
        if route == .child, who == nil { return }
        dismiss()
        onOpen(route, who)
    }
}

// MARK: - The bell

/// 🔔 The bell beside the ⚙️ on the parent home, with its unread badge.
struct ActivityBellButton: View {
    var unread: Int
    var style: Style = .circle
    var action: () -> Void

    enum Style { case circle, bare }

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            // The circle is EXACTLY the ⚙️'s 40×40 and nothing may displace it —
            // the badge used to be laid out beside it with compensating padding,
            // which pushed the bell a few points down and out of line with the
            // gear (Rani). It is an overlay now, so it floats over the corner
            // and the circle keeps the same size and baseline as the gear's.
            Image(systemName: "bell.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: style == .circle ? 40 : 28,
                       height: style == .circle ? 40 : 28)
                .background {
                    if style == .circle {
                        Circle().fill(Color.white.opacity(0.22))
                            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if unread > 0 { badge.offset(x: 5, y: -5) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unread > 0 ? tr("עדכונים — \(unread) חדשים") : tr("עדכונים"))
    }

    private var badge: some View {
        Text(unread > 9 ? "9+" : "\(unread)")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, unread > 9 ? 4 : 0)
            .frame(minWidth: 16, minHeight: 16)
            .background(Capsule().fill(Color(hex: "FF4D6D")))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
            .offset(x: 6, y: -5)
            // The count is text — never scaled (a `scaleEffect` on text blurs it
            // on this app's screens); it just appears.
            .transition(.opacity)
    }
}
