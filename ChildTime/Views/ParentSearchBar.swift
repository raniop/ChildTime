import SwiftUI

/// 🔎 On top of the parent's home: type what you want to do, tap the answer,
/// land on the page (Rani, 2026-10-24). See `ParentSearch`.
struct ParentSearchBar: View {
    let children: [Profile]
    let onPick: (ParentSearchTarget) -> Void

    #if DEBUG
    @State private var query = ProcessInfo.processInfo.environment["DEMO_SEARCH"] ?? ""   // screenshots
    #else
    @State private var query = ""
    #endif
    @FocusState private var focused: Bool

    private var results: [ParentSearchEntry] {
        ParentSearch.search(query, in: ParentSearch.entries(children: children))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GlassInk.secondary)
                TextField("", text: $query, prompt: Text(tr("מה תרצו לעשות? למשל: לשנות קוד הורה")).foregroundColor(GlassInk.tertiary))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { if let first = results.first { pick(first) } }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(GlassInk.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("ניקוי"))
                }
            }
            .padding(.horizontal, 14).frame(height: 48)
            .glassPane(radius: 16, strength: 0.14, shadow: false)

            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(spacing: 0) {
                    if results.isEmpty {
                        Text(tr("לא מצאתי. נסו במילים אחרות, למשל: זמן מסך, שעת שינה, מתנה"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        ForEach(results) { e in
                            Button { pick(e) } label: { row(e) }
                                .buttonStyle(.plain)
                            if e.id != results.last?.id { Divider().overlay(Color.white.opacity(0.14)).padding(.leading, 52) }
                        }
                    }
                }
                .glassPane(radius: 16, shadow: false)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: query.isEmpty)
        .environment(\.layoutDirection, .app)
    }

    private func row(_ e: ParentSearchEntry) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: e.icon).font(.system(size: 22)).frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).font(.system(size: 15.5, weight: .heavy, design: .rounded)).foregroundStyle(GlassInk.primary)
                Text(e.place).font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: AppSymbol.forwardChevron).font(.system(size: 13, weight: .bold)).foregroundStyle(GlassInk.tertiary)
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private func pick(_ e: ParentSearchEntry) {
        Haptic.light()
        focused = false
        query = ""
        onPick(e.target)
    }
}
