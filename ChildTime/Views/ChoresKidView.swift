import SwiftUI
import PhotosUI

/// 🧹 The kid's chores screen: the parent defined the chores, the kid does one
/// and ticks its box. The reward is always 🎮 play minutes (money was removed —
/// Rani), landing only after the parent approves. No failure language anywhere:
/// a returned chore just shows up as available again.
///
/// The look (Rani, 2026-10-13, chosen from nine directions — "ח"): a checklist
/// in pictures. The child's own buddy stands on top holding the day's prize,
/// every chore is one coloured row with a drawing of it (`ChoreArt`) and one
/// big box to tick, and a tick that reaches the parent is a small party.
struct ChoresKidView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var choreStore = ChoreStore.shared
    let onClose: () -> Void

    /// Reward picked → offering an optional 📸 proof photo before sending.
    @State private var pendingSend: (chore: Chore, reward: String)?
    @State private var showPhotoOffer = false
    @State private var showCamera = false
    @State private var libraryPickerPresented = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var justSent: Set<String> = []
    /// Chores whose "done" write is in flight (awaiting the server's ack).
    @State private var sending: Set<String> = []
    /// Set when a send couldn't reach the parent — a gentle "let's try again"
    /// (never failure language for a kid). The chore stays available.
    @State private var retryChoreID: String?
    /// 🎉 A chore has just reached the parent: confetti, the prize pops out of
    /// its row, and the buddy cheers — for a moment.
    @State private var justCelebrated: String?
    @State private var confetti = 0
    @ObservedObject private var display = DisplayGeometry.shared

    private var myChores: [Chore] {
        guard let id = profiles.activeID else { return [] }
        return choreStore.chores(forChild: id)
    }

    /// A chore is "handled for today" if it's been sent, is waiting for a
    /// parent, or was already approved today. Everything else is still to-do.
    private func isHandled(_ c: Chore) -> Bool {
        sending.contains(c.id) || justSent.contains(c.id)
            || c.isPendingApproval || (c.isDaily && c.approvedToday)
    }
    /// One list (Rani chose the checklist, 2026-10-13): what can be done now
    /// on top, what was handled today under it — a row slides down when its
    /// box is ticked.
    private var orderedChores: [Chore] { myChores.filter { !isHandled($0) } + myChores.filter(isHandled) }

    /// How many times a day this chore can be done (a one-off: once).
    private func turns(_ c: Chore) -> Int { c.isDaily ? max(1, c.timesPerDay) : 1 }
    /// Turns already done today — approved ones, plus the one on its way to a parent.
    private func turnsDone(_ c: Chore) -> Int {
        let onItsWay = (c.isPendingApproval || sending.contains(c.id) || justSent.contains(c.id)) ? 1 : 0
        return min(turns(c), (c.isDaily ? c.doneToday : 0) + onItsWay)
    }
    /// The play minutes still waiting today.
    private var minutesLeft: Int {
        myChores.reduce(0) { $0 + max($1.rewardMinutes, 0) * (turns($1) - turnsDone($1)) }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: hSize == .regular ? 2 : 1)
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 10) {
                        if myChores.isEmpty {
                            totalsCard
                            emptyState
                        } else {
                            buddyHero
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(orderedChores) { chore in choreRow(chore) }
                            }
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: orderedChores.map(\.id))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, AppSpacing.md)
                    .frame(maxWidth: hSize == .regular ? 860 : 560)
                    .frame(maxWidth: .infinity)
                }
            }
            FancyConfetti(trigger: confetti).allowsHitTesting(false)
        }
        .onAppear { choreStore.startIfNeeded() }
        // 📸 Optional proof photo — a picture beats a debate about whether the
        // room is really tidy (Rani).
        .confirmationDialog(tr("רוֹצִים לְצָרֵף תְּמוּנָה שֶׁל מַה שֶּׁעֲשִׂיתֶם? 📸"), isPresented: $showPhotoOffer,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(tr("📸 לְצַלֵּם עַכְשָׁו")) { showCamera = true }
            }
            Button(tr("🖼 לִבְחֹר תְּמוּנָה")) { libraryPickerPresented = true }
            Button(tr("לִשְׁלֹחַ בְּלִי תְּמוּנָה")) { finishSend(photo: nil) }
            Button(tr("בִּטּוּל"), role: .cancel) { pendingSend = nil }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                finishSend(photo: image.flatMap(compressProof))
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $libraryPickerPresented, selection: $libraryItem, matching: .images)
        .onChangeCompat(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                let photo = data.flatMap(UIImage.init(data:)).flatMap(compressProof)
                await MainActor.run {
                    libraryItem = nil
                    finishSend(photo: photo)
                }
            }
        }
        // Gentle recovery — the send didn't reach the parent. No blame, no
        // "failed"; the chore is still there to tap again.
        .alert(tr("רֶגַע! ✨"), isPresented: Binding(
            get: { retryChoreID != nil }, set: { if !$0 { retryChoreID = nil } })) {
            Button(tr("אוֹקֵיי")) { retryChoreID = nil }
        } message: {
            Text(tr("לֹא הִסְפַּקְנוּ לִשְׁלֹחַ לְאַבָּא אוֹ אִמָּא. נַסּוּ שׁוּב עוֹד רֶגַע 🙂"))
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptic.light()
                onClose()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.32), lineWidth: 1))
            }
            .accessibilityLabel(tr("חזרה"))
            Spacer()
            Text(tr("מַטְלוֹת הַבַּיִת 🧹"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .shadow(color: .black.opacity(0.18), radius: 7, y: 2)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        // On the foldable: the way back in the corner away from the clock, and
        // the title centred in the band beside it — the chores start below.
        .awayFromBar()
        .fillsTopBand(above: DisplayProbeView.minimumTopMargin + AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - The buddy on top, holding the day's prize

    /// The child's own character says how many play minutes are still waiting
    /// today; a segment per turn fills under it; and when a chore reaches the
    /// parent, the buddy is the one who cheers.
    private var buddyHero: some View {
        let total = myChores.reduce(0) { $0 + turns($1) }
        let done = myChores.reduce(0) { $0 + turnsDone($1) }
        let left = minutesLeft
        let cheering = justCelebrated != nil
        let totals = profiles.activeID.map { choreStore.totals(forChild: $0) } ?? (minutes: 0, coins: 0, paid: 0)
        let buddyWidth: CGFloat = display.isShort ? 64 : 92
        return VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 6) {
                ChoreBuddy(profile: profiles.active, width: buddyWidth)
                    .scaleEffect(cheering ? 1.12 : 1, anchor: .bottom)
                    .rotationEffect(.degrees(cheering ? -6 : 0), anchor: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    if cheering {
                        bubbleSmall(Gendered.g(tr("כָּל הַכָּבוֹד, אַלּוּף! 🎉"), tr("כָּל הַכָּבוֹד, אַלּוּפָה! 🎉")))
                    } else if left > 0 {
                        bubbleSmall(tr("עוֹד אֶפְשָׁר לְהַרְוִיחַ הַיּוֹם"))
                    }
                    if left > 0 {
                        Text(tr("🎮 \(left) דַּקּוֹת מִשְׂחָק"))
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                    } else {
                        Text(Gendered.g(tr("כָּל הַכָּבוֹד! סִיַּמְתָּ הַכֹּל לְהַיּוֹם"), tr("כָּל הַכָּבוֹד! סִיַּמְתְּ הַכֹּל לְהַיּוֹם")))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                .padding(.bottom, buddyWidth * 0.28)
                Spacer(minLength: 0)
            }
            // One segment per turn; a long list gets one plain bar.
            if total <= 12 {
                HStack(spacing: 5) {
                    ForEach(0..<max(total, 1), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(i < done ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(.white.opacity(0.25)))
                            .frame(height: 11)
                    }
                }
            } else {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Color(hex: "FFD23F"))
            }
            if totals.minutes > 0 {
                HStack(spacing: 6) {
                    Text("🏆").font(.system(size: 13))
                    Text(Gendered.g(tr("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:"), tr("סַךְ הַכֹּל הִרְוַחַתְּ מֵהַמַּטְלוֹת:")))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                    Text(tr("🎮 \(totals.minutes) דַּקּוֹת מִשְׂחָק"))
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: justCelebrated)
        .accessibilityElement(children: .combine)
    }

    private func bubbleSmall(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "2A1E5C").opacity(0.8))
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    /// 🏆 Lifetime earnings from chores — shown alone only while there are no chores.
    @ViewBuilder
    private var totalsCard: some View {
        let totals = profiles.activeID.map { choreStore.totals(forChild: $0) } ?? (minutes: 0, coins: 0, paid: 0)
        if totals.minutes > 0 {
            HStack(spacing: AppSpacing.md) {
                Text("🏆").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Gendered.g(tr("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:"), tr("סַךְ הַכֹּל הִרְוַחַתְּ מֵהַמַּטְלוֹת:")))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(tr("🎮 \(totals.minutes) דַּקּוֹת מִשְׂחָק"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(AppSpacing.md)
            .glassPane(radius: 16, tint: Color(hex: "FFD23F"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🧹").font(.system(size: 56))
            Text(tr("עוֹד אֵין מַטְלוֹת"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא לְהוֹסִיף מַטְלוֹת —\nוְתוּכְלוּ לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק אוֹ כֶּסֶף! 💪"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - One chore, one row

    /// The picture of the chore, its name, the prize in gold (or where it
    /// stands, once ticked), and ONE big box to tick. No failure language: a
    /// chore a parent sent back is simply an empty box again.
    private func choreRow(_ chore: Chore) -> some View {
        let handled = isHandled(chore)
        let isSending = sending.contains(chore.id)
        let approved = chore.isDaily && chore.approvedToday
        let tint = ChoreArt.tint(for: chore)
        let celebrating = justCelebrated == chore.id
        return HStack(spacing: 12) {
            ChorePicture(chore: chore, side: 92)
                .scaleEffect(1.1)
                // 🔊 A child who does not read yet hears what the chore is
                // (Sasha, 12.10: her גן daughter could not tell them apart).
                .overlay(alignment: .bottomLeading) {
                    if PreReaderGames.activeChildIsPreReader || (profiles.active?.effectiveGrade ?? 1) <= 1 {
                        PreReaderSpeakButton(spoken: chore.title, side: 32)
                            .background(Circle().fill(Color(hex: "2A1E5C").opacity(0.55)))
                            .offset(x: -6, y: 6)
                    }
                }
            VStack(alignment: .leading, spacing: 7) {
                Text(chore.title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.75)
                if handled {
                    Text(isSending ? tr("שׁוֹלְחִים… 📨")
                         : approved ? Gendered.g(tr("כָּל הַכָּבוֹד, אַלּוּף! 🎉"), tr("כָּל הַכָּבוֹד, אַלּוּפָה! 🎉"))
                         : tr("מְחַכִּים לְאִשּׁוּר 🕐"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    HStack(spacing: 8) {
                        // The prize, in gold — the one thing on the row that shines.
                        Text(rewardLine(chore))
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                        // A dot per turn today, for a chore done more than once a day.
                        if turns(chore) > 1 {
                            HStack(spacing: 5) {
                                ForEach(0..<turns(chore), id: \.self) { i in
                                    Circle()
                                        .fill(i < turnsDone(chore) ? Color(hex: "FFD23F") : .white.opacity(0.4))
                                        .frame(width: 9, height: 9)
                                }
                            }
                            .accessibilityLabel(tr("הַיּוֹם: \(chore.doneToday)/\(chore.timesPerDay) ✔️"))
                        }
                    }
                }
            }
            Spacer(minLength: 2)
            Button {
                Haptic.success()
                tapDone(chore)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(handled && !isSending ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(.white.opacity(0.18)))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white, lineWidth: handled && !isSending ? 0 : 3)
                    if isSending {
                        ProgressView().tint(.white)
                    } else if handled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
                .frame(width: 60, height: 60)
                .scaleEffect(celebrating ? 1.18 : 1)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!handled)   // not `.disabled`: that greys the gold ✓ out
            .accessibilityLabel(handled ? chore.title : tr("עָשִׂיתִי! ✅"))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(handled ? 0.3 : 0.72), tint.opacity(handled ? 0.14 : 0.36)],
                                 startPoint: .leading, endPoint: .trailing)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 1))
        // The prize pops out of the row as it goes to the parent.
        .overlay(alignment: .top) {
            if celebrating {
                Text(rewardLine(chore))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .lineLimit(1)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    .offset(y: -20)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.5)))
            }
        }
        .zIndex(celebrating ? 2 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: justCelebrated)
    }

    private func rewardLine(_ c: Chore) -> String {
        tr("🎮 \(max(c.rewardMinutes, 0)) דַּקּוֹת מִשְׂחָק")
    }

    /// The kid tapped "עשיתי" — reward is always play-minutes; go to the photo
    /// offer (no picker, since money was removed).
    private func tapDone(_ chore: Chore) {
        // Reward is always play-minutes now (money removed) — no picker needed.
        offerPhoto(chore, reward: "minutes")
    }

    private func offerPhoto(_ chore: Chore, reward: String) {
        pendingSend = (chore, reward)
        showPhotoOffer = true
    }

    private func finishSend(photo: Data?) {
        guard let p = pendingSend else { return }
        pendingSend = nil
        send(p.chore, reward: p.reward, photo: photo)
    }

    /// ~900px JPEG ≈ 100-200KB — comfortably inside the 1MB Firestore doc cap.
    private func compressProof(_ image: UIImage) -> Data? {
        let maxEdge: CGFloat = 900
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.55)
    }

    private func send(_ chore: Chore, reward: String, photo: Data?) {
        // Show "שולחים…" while we WAIT for the server to confirm — no fake
        // celebration for a write that might not have reached the parent (Noa's
        // bug: chores marked done that never arrived). markDone self-heals a
        // drifted membership and retries, so this is honest, not slow-by-default.
        sending.insert(chore.id)
        Task {
            let result: ChoreStore.SendResult
            #if DEBUG
            // DEMO_SCREEN=choreskid has no family to send to: play the answer of one.
            if ProcessInfo.processInfo.environment["DEMO_SCREEN"] == "choreskid" {
                try? await Task.sleep(nanoseconds: 700_000_000)
                choreStore.markDemoPending(chore)
                result = .sent
            } else {
                result = await choreStore.markDone(chore, reward: reward, photo: photo)
            }
            #else
            result = await choreStore.markDone(chore, reward: reward, photo: photo)
            #endif
            sending.remove(chore.id)
            switch result {
            case .sent, .queued:
                // Latency bridge only — the listener flips isPendingApproval
                // within a beat; without this an APPROVED chore would keep
                // showing "מחכים לאישור" for the rest of the session.
                justSent.insert(chore.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { justSent.remove(chore.id) }
                Haptic.success()
                SoundPlayer.shared.play(.portalAppear)
                // 🎉 Only now — the chore really reached the parent.
                justCelebrated = chore.id
                confetti += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    if justCelebrated == chore.id { justCelebrated = nil }
                }
            case .failed, .notReady:
                // Never failure language for a kid (safe-negative-experience) —
                // a gentle "let's try again" and the chore stays available.
                retryChoreID = chore.id
                Haptic.light()
            }
        }
    }
}

/// Minimal camera sheet for the chore proof photo (PhotosPicker has no camera).
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil) }
    }
}

/// The child's own character, standing still (the screen's buddy is not the
/// roaming companion: it only holds the prize and cheers).
private struct ChoreBuddy: View {
    var profile: Profile?
    var width: CGFloat = 92

    var body: some View {
        Group {
            if let profile,
               let img = profile.character.uiImage
                ?? CharacterSnapshot.image(modelName: profile.character.scn, pixelSize: width * 2) {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Text("🧹").font(.system(size: width * 0.7))
            }
        }
        .frame(width: width, height: width * 1.22)
        .accessibilityHidden(true)
    }
}
