import SwiftUI
import Combine
import PhotosUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Floating buttons (parent dashboard)

/// 💬 The round chat button in the corner of the parent home — and, for the
/// team's own accounts only, the green inbox button above it.
struct SupportFloatingButtons: View {
    @ObservedObject private var store = SupportChatStore.shared
    let showsInbox: Bool
    let onChat: () -> Void
    let onInbox: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if showsInbox {
                Button {
                    Haptic.light()
                    onInbox()
                } label: {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(AppGradient.success, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
                        .overlay(alignment: .topTrailing) { badge(store.teamAwaitingReply) }
                }
                .buttonStyle(.juicy)
                .accessibilityLabel(tr("כל השיחות"))
            }
            // On the team's own phones the 💬 button is pointless — it would
            // open a chat with ourselves. One button there: the inbox.
            if !showsInbox {
            Button {
                Haptic.light()
                onChat()
            } label: {
                Text("💬")
                    .font(.system(size: 26))
                    .frame(width: 58, height: 58)
                    .background(AppGradient.gold, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    .overlay(alignment: .topTrailing) { badge(store.parentUnread) }
            }
            .buttonStyle(.juicy)
            .accessibilityLabel(tr("שיחה עם צוות טופי"))
            }
        }
    }

    @ViewBuilder private func badge(_ n: Int) -> some View {
        if n > 0 {
            Text(n > 99 ? "99+" : "\(n)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "FF3B4E")))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: 1.5))
                .offset(x: 6, y: -6)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Presenting a route

/// The sheet content for a `SupportChatRoute`.
struct SupportChatRouteView: View {
    let route: SupportChatRoute

    var body: some View {
        Group {
            switch route {
            case .parent(let hid):
                NavigationStack { SupportChatView(householdID: hid, mode: .parent, showsClose: true) }
            case .inbox:
                SupportInboxView()
            case .teamThread(let hid):
                NavigationStack {
                    SupportChatView(householdID: hid, mode: .team, showsClose: true)
                }
            }
        }
        .environment(\.layoutDirection, .app)
    }
}

// MARK: - The thread

/// Live messages of one family's thread.
@MainActor
final class SupportThreadModel: ObservableObject {
    @Published private(set) var messages: [SupportMessage] = []
    @Published private(set) var loaded = false
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    func start(householdID: String) {
        #if canImport(FirebaseFirestore)
        guard listener == nil, !HouseholdManager.skipsCloudSync else { loaded = true; return }
        // Unordered on the server, sorted here: our own message carries only an
        // ESTIMATED server time until the write lands, and must still sit last.
        listener = SupportChatStore.shared.messagesQuery(householdID: householdID)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snap, error in
                if let error { print("[Support] thread listen failed: \(error.localizedDescription)") }
                let list = (snap?.documents ?? []).compactMap { SupportMessage($0) }
                    .sorted { ($0.at ?? .distantFuture) < ($1.at ?? .distantFuture) }
                Task { @MainActor in
                    self?.messages = list
                    self?.loaded = true
                }
            }
        #else
        loaded = true
        #endif
    }

    /// 🖼 Fill the thread from a fixed local list, for a miniature on a story
    /// card. No listener is opened, so nothing is fetched and nothing is read.
    func seedPreview(_ list: [SupportMessage]) {
        guard messages.isEmpty else { return }
        messages = list
        loaded = true
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove(); listener = nil
        #endif
    }
}

/// One chat screen — the parent's with the team, or the team inside a family's
/// thread. "Mine" sits on the trailing side in gold; the other side on the
/// leading side in light bubbles with a small name line. On the PARENT side the
/// name line is always "צֶוֶת טוֹפִּי" — never who on the team wrote.
struct SupportChatView: View {
    enum Mode { case parent, team }

    let householdID: String
    let mode: Mode
    var showsClose: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isInertPreview) private var inertPreview
    @StateObject private var model = SupportThreadModel()
    @ObservedObject private var store = SupportChatStore.shared
    @State private var draft = ""
    @State private var sending = false
    @State private var failed = false
    /// 📷 A screenshot picked for the next message (already shrunk to send).
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var attachment: Data?
    @State private var attachmentTooBig = false
    /// A tapped image, shown full screen.
    @State private var viewingImage: UIImage?
    @FocusState private var focused: Bool

    private var summary: SupportChatSummary? { store.teamChats.first { $0.id == householdID } }

    private var title: String {
        switch mode {
        case .parent: return tr("צוות טופי")
        case .team:
            let name = summary?.familyName ?? ""
            return name.isEmpty ? tr("משפחה ללא שם") : name
        }
    }
    private var subtitle: String {
        switch mode {
        case .parent: return tr("נחזור אליכם בהקדם")
        case .team: return summary?.kidsSummary ?? ""
        }
    }

    /// 🖼 The exchange a story card shows. Fixed, so the card reads the same
    /// way every time, and local, so nothing is fetched to draw it.
    static var previewThread: [SupportMessage] {
        let now = Date()
        // ⚠️ No greeting here: `messageList` renders "שלום! כאן צוות טופי" on
        // every parent chat without storing it, so seeding one too showed it
        // twice on the card.
        return [
            SupportMessage(id: "p2", text: tr("איך מחברים את האייפד לילדה שלי?"),
                           from: .parent, senderUID: "", senderName: "",
                           at: now.addingTimeInterval(-420)),
            SupportMessage(id: "p3", text: tr("בהגדרות של האייפד בוחרים \"זה המכשיר של הילד\" ומזינים את קוד המשפחה 🙂"),
                           from: .team, senderUID: "", senderName: tr("צוות טופי"),
                           at: now.addingTimeInterval(-360)),
        ]
    }

    private var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil) && !sending
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                messageList
                inputBar
            }
        }
        .fullScreenCover(isPresented: Binding(get: { viewingImage != nil }, set: { if !$0 { viewingImage = nil } })) {
            if let viewingImage { SupportImageViewer(image: viewingImage) { self.viewingImage = nil } }
        }
        // 📷 Picked → a full screen to look at it, add a caption and send — the
        // WhatsApp / Telegram way (Rani: the thumbnail by the field wasn't clear).
        .fullScreenCover(isPresented: Binding(get: { attachment != nil }, set: { if !$0 { attachment = nil; pickedPhoto = nil } })) {
            if let attachment, let ui = UIImage(data: attachment) {
                SupportImageComposer(image: ui, caption: $draft, sending: sending,
                                     onCancel: { self.attachment = nil; pickedPhoto = nil },
                                     onSend: { send() })
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { header }
            if showsClose {
                ToolbarItem(placement: .awayFromBar(.cancellationAction, leading: true)) {
                    Button(tr("סגירה")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            // 🖼 A miniature of this screen on a story card must not open a
            // listener, must not mark the thread read and must not clear the
            // parent's notifications — it shows a fixed exchange and nothing
            // else happens.
            guard !inertPreview else {
                #if DEBUG
                // DEMO_SCREEN=supportchat — the thread with a screenshot in it.
                if ProcessInfo.processInfo.environment["DEMO_SCREEN"] == "supportchat",
                   let shot = ProcessInfo.processInfo.environment["DEMO_IMAGE"].flatMap(UIImage.init(contentsOfFile:))
                        ?? Character2DImages.image("lion"),
                   let jpg = SupportImage.prepare(shot.pngData() ?? Data()) {
                    var thread = Self.previewThread
                    thread.insert(SupportMessage(id: "p0", text: tr("זה מה שמופיע לי במסך"), from: .parent,
                                                 at: Date().addingTimeInterval(-300)), at: thread.count)
                    thread[thread.count - 1].imageBase64 = jpg.base64EncodedString()
                    model.seedPreview(thread)
                    if ProcessInfo.processInfo.environment["DEMO_COMPOSER"] != nil { attachment = jpg }
                    return
                }
                #endif
                model.seedPreview(Self.previewThread); return
            }
            model.start(householdID: householdID)
            store.visibleHouseholdID = householdID
            if mode == .parent { store.markParentRead(householdID: householdID) }
            clearDeliveredPushes()
        }
        .onDisappear {
            guard !inertPreview else { return }
            model.stop()
            if store.visibleHouseholdID == householdID { store.visibleHouseholdID = nil }
        }
    }

    /// The chat is open — its banners in Notification Center have done their job.
    private func clearDeliveredPushes() {
        let hid = householdID
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { list in
            let ids = list.filter {
                let info = $0.request.content.userInfo
                return info["type"] as? String == "support-chat" && info["householdID"] as? String == hid
            }.map(\.request.identifier)
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
        }
    }

    private var header: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(1)
            }
        }
    }

    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    if mode == .parent {
                        // Rendered here, never stored — every chat opens with it.
                        bubble(text: tr("שלום! כאן צוות טופי 👋 איך אפשר לעזור?"),
                               mine: false, name: tr("צוות טופי"), at: nil, pending: false)
                    }
                    ForEach(model.messages) { m in
                        let mine = (mode == .parent) == (m.from == .parent)
                        bubble(text: m.text, mine: mine, name: mine ? nil : nameLine(for: m),
                               at: m.at, pending: m.pending, image: m.imageBase64)
                            .id(m.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            // A tap anywhere on the conversation closes the keyboard (Rani). A
            // simultaneous gesture, so taps on a screenshot still open it.
            .simultaneousGesture(TapGesture().onEnded { focused = false })
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChangeCompat(of: model.messages.count) { _, _ in scrollToBottom(proxy, animated: true) }
            .onChangeCompat(of: focused) { _, isOn in
                if isOn { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToBottom(proxy, animated: true) } }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            // A short chat that fits on screen must stay pinned to the TOP —
            // scrolling a not-yet-laid-out list "to the bottom" pushed the first
            // bubbles down and left an empty band above them (Rani, 2026-10-03).
            guard contentHeight > viewportHeight + 1 else { return }
            if animated { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
            else { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    /// The small line above an incoming bubble.
    private func nameLine(for m: SupportMessage) -> String {
        switch mode {
        case .parent:
            return tr("צוות טופי")       // never the team member's own name
        case .team:
            if m.from == .team { return m.senderName.isEmpty ? tr("צוות טופי") : m.senderName }
            if !m.senderName.isEmpty { return m.senderName }
            if let p = summary?.parentName, !p.isEmpty { return p }
            return tr("הורה")
        }
    }

    @ViewBuilder
    private func bubble(text: String, mine: Bool, name: String?, at: Date?, pending: Bool, image: String? = nil) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if let name {
                    Text(name)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .padding(.horizontal, 6)
                }
                if let image, let ui = SupportImageCache.image(image) {
                    Button { viewingImage = ui } label: {
                        // The frame IS the picture's own shape — a fixed box left an
                        // empty bordered band beside a tall screenshot.
                        let aspect = ui.size.width / max(1, ui.size.height)
                        let h = min(320, 220 / max(0.01, aspect))
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(width: h * aspect, height: h)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1))
                            .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("צילום מסך"))
                }
                if !text.isEmpty {
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(mine ? Color(hex: "3A2600") : AppColor.textOnLight)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(mine ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.93)))
                    )
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
                }
                if let at {
                    HStack(spacing: 4) {
                        if pending { Image(systemName: "clock").font(.system(size: 9, weight: .bold)) }
                        Text(Self.timeLabel(at))
                    }
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.tertiary)
                    .padding(.horizontal, 6)
                }
            }
            if !mine { Spacer(minLength: 48) }
        }
    }

    private static func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        if Calendar.current.isDateInToday(date) {
            f.dateStyle = .none
        } else {
            f.dateStyle = .short
        }
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if failed {
                Text(tr("ההודעה לא נשלחה — נסו שוב"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.warn)
            }
            if attachmentTooBig {
                Text(tr("התמונה גדולה מדי — נסו צילום מסך אחר"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.warn)
            }
            HStack(alignment: .bottom, spacing: 10) {
                // 📷 A screenshot from the photos — "שלחו לנו צילום מסך" had no way
                // to be done from inside the chat (Rani).
                PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassPane(radius: 16, strength: 0.18, shadow: false)
                }
                .accessibilityLabel(tr("צירוף צילום מסך"))
                .onChangeCompat(of: pickedPhoto) { _, item in
                    guard let item else { return }
                    Task {
                        let raw = try? await item.loadTransferable(type: Data.self)
                        let ready = raw.flatMap(SupportImage.prepare)
                        attachment = ready
                        attachmentTooBig = raw != nil && ready == nil
                        if failed { failed = false }
                    }
                }
                TextField(tr("כתבו הודעה…"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .glassPane(radius: 16, strength: 0.18, shadow: false)
                    .onChangeCompat(of: draft) { _, v in
                        if v.count > SupportChatStore.textLimit { draft = String(v.prefix(SupportChatStore.textLimit)) }
                        if failed { failed = false }
                    }
                Button(action: send) {
                    Group {
                        if sending { ProgressView().tint(Color(hex: "3A2600")) }
                        else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color(hex: "3A2600"))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppGradient.gold, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    .opacity(canSend || sending ? 1 : 0.5)
                }
                .buttonStyle(.juicy)
                .disabled(!canSend)
                .accessibilityLabel(tr("שלח"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private func send() {
        let text = draft
        let image = attachment
        guard canSend else { return }
        sending = true
        failed = false
        draft = ""
        attachment = nil; pickedPhoto = nil
        Haptic.light()
        Task {
            let ok = await store.send(text, householdID: householdID, asTeam: mode == .team, image: image)
            sending = false
            if !ok {
                // Nothing is lost: the text and the picture go back.
                failed = true
                if draft.isEmpty { draft = text }
                if attachment == nil { attachment = image }
            }
        }
    }
}

// MARK: - The team's inbox

/// "כָּל הַשִּׂיחוֹת" — every family that wrote in, newest first. A dot marks
/// the chats whose last word is the parent's (waiting for us).
struct SupportInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SupportChatStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                if store.teamChats.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Text("📭").font(.system(size: 54))
                        Text(tr("אין עדיין שיחות"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.teamChats) { chat in
                                NavigationLink {
                                    SupportChatView(householdID: chat.id, mode: .team)
                                } label: {
                                    row(chat)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(tr("כל השיחות"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .awayFromBar(.cancellationAction, leading: true)) {
                    Button(tr("סגירה")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .tint(.white)
        .onAppear { store.startTeamIfNeeded() }
    }

    private func row(_ chat: SupportChatSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(chat.needsReply ? Color(hex: "FF3B4E") : .clear)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.familyName.isEmpty ? tr("משפחה ללא שם") : chat.familyName)
                        .font(.system(size: 16, weight: chat.needsReply ? .heavy : .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let at = chat.lastAt {
                        Text(Self.relative(at))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.tertiary)
                    }
                }
                if !chat.kidsSummary.isEmpty {
                    Text(chat.kidsSummary)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1)
                }
                Text((chat.lastFrom == "team" ? "↩︎ " : "") + chat.lastText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(chat.needsReply ? GlassInk.primary : GlassInk.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: AppSymbol.forwardChevron)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GlassInk.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .glassPane(radius: 16)
        .contentShape(Rectangle())
    }

    private static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// Decoded screenshots, so a chat re-render doesn't decode base64 again.
enum SupportImageCache {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(_ base64: String) -> UIImage? {
        let key = String(base64.prefix(64) + base64.suffix(64) + "\(base64.count)") as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let data = Data(base64Encoded: base64), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }
}

/// A tapped screenshot, full screen; tap anywhere to close.
struct SupportImageViewer: View {
    let image: UIImage
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit().padding()
        }
        .onTapGesture(perform: onClose)
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.2)))
            }
            .padding()
            .accessibilityLabel(tr("סגירה"))
        }
    }
}

/// 📷 The picked screenshot, big, with a caption field and a send button.
struct SupportImageComposer: View {
    let image: UIImage
    @Binding var caption: String
    let sending: Bool
    let onCancel: () -> Void
    let onSend: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                    .accessibilityLabel(tr("ביטול"))
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = false }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField(tr("הוסיפו הערה…"), text: $caption, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    Button(action: onSend) {
                        Group {
                            if sending { ProgressView().tint(Color(hex: "3A2600")) }
                            else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Color(hex: "3A2600"))
                            }
                        }
                        .frame(width: 48, height: 48)
                        .background(AppGradient.gold, in: Circle())
                    }
                    .buttonStyle(.juicy)
                    .disabled(sending)
                    .accessibilityLabel(tr("שלח"))
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .environment(\.layoutDirection, .app)
    }
}
