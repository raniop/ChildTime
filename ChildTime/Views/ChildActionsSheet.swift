import SwiftUI

/// "⚡ פעולות" — what a parent does for ONE child, in one short window
/// (Rani approved the mockup 2026-10-08). It replaced a menu of 14 items:
/// the two remote controls up top as big tiles, then the three places a parent
/// goes next. Everything else lives where it belongs — editing on the ✏️ by
/// the name, the device on the card, deletion in the child's settings.
///
/// The sheet only reports what was chosen; the dashboard closes it and runs
/// the action, so the dialogs and sheets that follow open over the home and
/// not over a sheet that is already leaving.
struct ChildActionsSheet: View {
    enum Action {
        case gift(minutes: Int)
        case lock
        case lockAndRevokeGift
        case location
        case connectDevice
        case screenTime
        case chores
        case settings
    }

    let profile: Profile
    let hasDevice: Bool
    /// "16 מתוך 60 דקות היום" / "משחקת עכשיו · נשארו 12:40".
    let statusLine: String
    let screenTimeSummary: String
    let pendingChores: Int
    let onAction: (Action) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Tile? = nil

    private enum Tile { case gift, lock }

    private var name: String { Question.stripNiqqud(profile.name) }
    private var girl: Bool { profile.gender == .girl }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if hasDevice {
                    tiles
                    if let expanded { choices(expanded) }
                } else {
                    connectRow
                }
                rows
            }
            .padding(20)
            .foregroundStyle(GlassInk.primary)
            .animation(.snappy(duration: 0.25), value: expanded)
        }
        .background(GlassBackdrop().ignoresSafeArea())
        .environment(\.layoutDirection, .app)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(profile: profile, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GlassInk.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סגירה"))
        }
    }

    // MARK: - The two remote controls + where

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("💝", tr("מתנת דקות"), on: expanded == .gift) { toggle(.gift) }
            tile("🔒", tr("נעילה"), on: expanded == .lock) { toggle(.lock) }
            tile("📍", tr("איפה \(name)"), on: false) { run(.location) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ t: Tile) {
        Haptic.light()
        expanded = expanded == t ? nil : t
    }

    @ViewBuilder private func choices(_ t: Tile) -> some View {
        switch t {
        case .gift:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                chip(tr("רבע שעה")) { run(.gift(minutes: 15)) }
                chip(tr("חצי שעה")) { run(.gift(minutes: 30)) }
                chip(tr("שעה")) { run(.gift(minutes: 60)) }
                chip(tr("שעתיים")) { run(.gift(minutes: 120)) }
                chip(tr("4 שעות")) { run(.gift(minutes: 240)) }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        case .lock:
            VStack(spacing: 8) {
                chip(tr("נעל עכשיו")) { run(.lock) }
                chip(tr("נעל ואפס דקות מתנה"), destructive: true) { run(.lockAndRevokeGift) }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var connectRow: some View {
        Button {
            run(.connectDevice)
        } label: {
            Text(tr("+ חברו מכשיר ל\(name)"))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "4B3FBF"))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Where to go next

    private var rows: some View {
        VStack(spacing: 0) {
            row("⏳", tr("זמן מסך יומי"), screenTimeSummary) { run(.screenTime) }
            divider
            row("🧹", tr("מטלות הבית"),
                pendingChores > 0 ? tr("מחכות לאישור: \(pendingChores)") : tr("משימות ופרסים בבית")) {
                run(.chores)
            }
            divider
            row("⚙️", tr("כל ההגדרות של \(name)"), tr("זמן, למידה, שפה ומכשיר")) { run(.settings) }
        }
        .glassPane(radius: 20)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.leading, 58)
    }

    private func run(_ a: Action) {
        Haptic.light()
        onAction(a)
    }

    // MARK: - Pieces

    private func tile(_ emoji: String, _ title: String, on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 28))
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(on ? Color(hex: "4B3FBF") : GlassInk.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(on ? Color.white.opacity(0.92) : Color.white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, destructive: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title)
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                .foregroundStyle(destructive ? Color(hex: "C2334D") : Color(hex: "4B3FBF"))
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.white.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ emoji: String, _ title: String, _ sub: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 22)).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(sub)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Image(systemName: AppSymbol.forwardChevron)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GlassInk.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
