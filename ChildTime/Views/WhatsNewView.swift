import SwiftUI

/// ✨ "מה חדש" — the once-per-update sheet on the PARENT dashboard.
///
/// It shows ONLY what arrived since the build this install last saw. Everything
/// older lives one tap away in `WhatsNewHistoryView`, instead of stacking on top
/// of the new thing on every upload (Rani: "מה הגבול?").
///
/// `release` pins the sheet to one entry — that is the history screen reusing
/// this exact layout for an older update, which is what Rani asked for:
/// "לחיצה עליה תביא מה היה השינוי בגרסא הזאת".
struct WhatsNewView: View {
    var release: WhatsNewContent.Release? = nil
    let onDone: () -> Void

    @State private var showHistory = false

    /// What this sheet lists. Re-opened by hand after everything was already
    /// seen, it falls back to the newest update rather than showing nothing.
    private var items: [WhatsNewContent.Item] {
        if let release { return release.items }
        let unseen = WhatsNewContent.unseenItems
        return unseen.isEmpty ? (WhatsNewContent.releases.first?.items ?? []) : unseen
    }

    /// How many updates this catches the parent up on. Reading one is "the
    /// latest update"; reading four deserves saying so.
    private var updateCount: Int {
        release == nil ? max(1, WhatsNewContent.unseenReleases.count) : 1
    }

    private var subtitle: String {
        if release != nil { return tr("מה היה בעדכון הזה") }
        return updateCount > 1
            ? tr("הנה מה שהוספנו ב־\(updateCount) העדכונים האחרונים")
            : tr("הנה מה שהוספנו בעדכון האחרון")
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("✨").font(.system(size: 44))
                    Text(tr("מה חדש בטופי?"))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .multilineTextAlignment(.center)
                    // The version itself, so a parent can say WHICH Tofy they have.
                    Text(tr("גרסה \(release?.version ?? WhatsNewContent.currentVersion)"))
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        .padding(.top, 4)
                }
                .padding(.top, 28)
                .padding(.bottom, 18)
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            WhatsNewRow(item: item)
                        }

                        // Everything older, on purpose out of the way.
                        if release == nil {
                            Button {
                                Haptic.light()
                                showHistory = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text("🗂").font(.system(size: 16))
                                    Text(tr("כל העדכונים הקודמים"))
                                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .glassPane(radius: 16, shadow: false)
                            }
                            .buttonStyle(.juicy)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text(release == nil ? tr("מעולה, תודה! 💛") : tr("סגירה"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .frame(maxWidth: 420)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.92)))
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .environment(\.layoutDirection, .app)
        .sheet(isPresented: $showHistory) {
            WhatsNewHistoryView(onDone: { showHistory = false })
        }
    }
}

/// One note. Shared by the sheet and the history detail so an old update looks
/// exactly like a new one.
private struct WhatsNewRow: View {
    let item: WhatsNewContent.Item

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(item.line)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassPane(radius: 16, shadow: false)
    }
}

/// 🗂 Every update Tofy has had, newest first. Tapping one opens that update's
/// notes in the same sheet the parent already knows.
struct WhatsNewHistoryView: View {
    let onDone: () -> Void

    @State private var opened: WhatsNewContent.Release?

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 10, size: 10)

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("🗂").font(.system(size: 40))
                    Text(tr("כל העדכונים"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
                    Text(tr("לחיצה על עדכון מראה מה השתנה בו"))
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                }
                .padding(.top, 26)
                .padding(.bottom, 16)
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(WhatsNewContent.releases) { release in
                            Button {
                                Haptic.light()
                                opened = release
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Text(release.items.first?.emoji ?? "✨")
                                        .font(.system(size: 26))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(release.headline)
                                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.leading)
                                        Text(countLine(release))
                                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.72))
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(12)
                                .glassPane(radius: 16, shadow: false)
                            }
                            .buttonStyle(.juicy)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    Haptic.light()
                    onDone()
                } label: {
                    Text(tr("סגירה"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .frame(maxWidth: 420)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.92)))
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .environment(\.layoutDirection, .app)
        .sheet(item: $opened) { release in
            WhatsNewView(release: release, onDone: { opened = nil })
        }
    }

    /// "3 שינויים · גרסה 2026.9.1" — a parent should be able to say which Tofy
    /// they have, and how much an old update actually carried.
    private func countLine(_ release: WhatsNewContent.Release) -> String {
        let n = release.items.count
        let changes = n == 1 ? tr("שינוי אחד") : tr("\(n) שינויים")
        return "\(changes) · \(tr("גרסה \(release.version)"))"
    }
}
