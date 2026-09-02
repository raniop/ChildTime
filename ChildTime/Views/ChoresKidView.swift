import SwiftUI
import PhotosUI

/// 🧹 The kid's chores screen: the parent defined the chores, the kid does one
/// and taps "עשיתי!". The reward is always 🎮 play minutes (money was removed —
/// Rani), landing only after the parent approves. No failure language anywhere:
/// a returned chore just shows up as available again.
struct ChoresKidView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var choreStore = ChoreStore.shared
    let onClose: () -> Void

    /// 👦👧 Gendered accent: the action button + the "done" trophy card take the
    /// child's own colours — blue-teal for a boy, pink-purple for a girl (Rani).
    private var accentColors: [Color] {
        switch profiles.active?.gender {
        case .girl: return [Color(hex: "FF5FA2"), Color(hex: "B15EFF")]
        case .boy:  return [Color(hex: "3A86FF"), Color(hex: "00C2CB")]
        default:    return [Color(hex: "06D6A0"), Color(hex: "48BFE3")]
        }
    }
    /// Single accent (for tints) — the first stop of the gendered pair.
    private var accentColor: Color { accentColors.first ?? Color(hex: "06D6A0") }

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
    /// The main grid: only chores the kid can DO right now (clean action button).
    private var todoChores: [Chore] { myChores.filter { !isHandled($0) } }
    /// The "בוצעו היום" bucket: sent / waiting-for-approval / approved-today.
    private var doneChores: [Chore] { myChores.filter { isHandled($0) } }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md),
              count: hSize == .regular ? 3 : 2)
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        totalsCard
                        if myChores.isEmpty {
                            emptyState
                        } else {
                            // Only actionable chores in the main grid — a clean
                            // "עשיתי!" call to action, never mixed with "done"
                            // badges (Rani: the mix was confusing).
                            if !todoChores.isEmpty {
                                LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                                    ForEach(todoChores) { chore in activeCard(chore) }
                                }
                            } else {
                                allDoneBanner
                            }
                            // Everything finished today drops into its own
                            // friendly "בוצעו היום" section below.
                            if !doneChores.isEmpty { doneSection }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.lg)
                    .frame(maxWidth: hSize == .regular ? 860 : 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { choreStore.startIfNeeded() }
        // 📸 Optional proof photo — a picture beats a debate about whether the
        // room is really tidy (Rani).
        .confirmationDialog("רוֹצִים לְצָרֵף תְּמוּנָה שֶׁל מַה שֶּׁעֲשִׂיתֶם? 📸", isPresented: $showPhotoOffer,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("📸 לְצַלֵּם עַכְשָׁו") { showCamera = true }
            }
            Button("🖼 לִבְחֹר תְּמוּנָה") { libraryPickerPresented = true }
            Button("לִשְׁלֹחַ בְּלִי תְּמוּנָה") { finishSend(photo: nil) }
            Button("בִּטּוּל", role: .cancel) { pendingSend = nil }
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
        .alert("רֶגַע! ✨", isPresented: Binding(
            get: { retryChoreID != nil }, set: { if !$0 { retryChoreID = nil } })) {
            Button("אוֹקֵיי") { retryChoreID = nil }
        } message: {
            Text("לֹא הִסְפַּקְנוּ לִשְׁלֹחַ לְאַבָּא אוֹ אִמָּא. נַסּוּ שׁוּב עוֹד רֶגַע 🙂")
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
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("חזרה")
            Spacer()
            VStack(spacing: 2) {
                Text("מַטְלוֹת הַבַּיִת 🧹")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("עוֹזְרִים בַּבַּיִת — וּבוֹחֲרִים פְּרָס!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    /// 🏆 Lifetime earnings from chores — "how much have I made, ever".
    @ViewBuilder
    private var totalsCard: some View {
        let totals = profiles.activeID.map { choreStore.totals(forChild: $0) } ?? (minutes: 0, coins: 0, paid: 0)
        if totals.minutes > 0 {
            HStack(spacing: AppSpacing.md) {
                Text("🏆").font(.system(size: 30))
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Gendered.g("סַךְ הַכֹּל הִרְוַחְתָּ מֵהַמַּטְלוֹת:", "סַךְ הַכֹּל הִרְוַחְתְּ מֵהַמַּטְלוֹת:"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("🎮 \(totals.minutes) דַּקּוֹת מִשְׂחָק")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🧹").font(.system(size: 56))
            Text("עוֹד אֵין מַטְלוֹת")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא לְהוֹסִיף מַטְלוֹת —\nוְתוּכְלוּ לְהַרְוִיחַ דַּקּוֹת מִשְׂחָק אוֹ כֶּסֶף! 💪")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    /// A chore the kid can DO now — emoji, name, reward, and the one clear
    /// action button. No status badges here (those live in the done section).
    @ViewBuilder
    private func activeCard(_ chore: Chore) -> some View {
        VStack(spacing: 8) {
            Text(chore.emoji).font(.system(size: 38))
            Text(chore.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(minHeight: 38)
            // ONE reward line — three separate chips + "אוֹ" overflowed the
            // 2-up grid card and truncated into "…5" (Rani caught it live).
            Text(rewardLine(chore))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.55)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(.white.opacity(0.16), in: Capsule())
            // Same-day repeat counter — reserved even when absent so every
            // card in a grid row keeps the same height.
            Text(chore.timesPerDay > 1 ? "הַיּוֹם: \(chore.doneToday)/\(chore.timesPerDay) ✔️" : " ")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(height: 13)

            Button {
                Haptic.success()
                tapDone(chore)
            } label: {
                Text("עָשִׂיתִי! ✅")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: accentColors,
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    /// 🎉 "בוצעו היום" card. APPROVED chores become a gendered "champion" card —
    /// the child's own colour, a 👑, and a personal cheer ("אלוף!" / "אלופה!").
    /// Still-in-flight ones (sent / waiting for a parent) keep a plain status so
    /// the crown means "really done", not "maybe".
    @ViewBuilder
    private func doneCard(_ chore: Chore) -> some View {
        let approved = chore.isDaily && chore.approvedToday
        let waiting = !approved && !sending.contains(chore.id)
        VStack(spacing: 6) {
            Text(approved ? "👑" : chore.emoji).font(.system(size: 30))
            Text(chore.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1).minimumScaleFactor(0.7)
            if sending.contains(chore.id) {
                statusCapsule("שׁוֹלְחִים… 📨", background: .white.opacity(0.18))
            } else if waiting {
                statusCapsule("מְחַכִּים לְאִשּׁוּר 🕐", background: Color(hex: "F4A261").opacity(0.55))
            } else {
                Text(Gendered.g("כָּל הַכָּבוֹד, אַלּוּף! 🎉", "כָּל הַכָּבוֹד, אַלּוּפָה! 🎉"))
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        // Approved → the child's gendered colour fills the card; otherwise the
        // neutral translucent look.
        .background(approved ? accentColor.opacity(0.28) : .white.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(approved ? accentColor.opacity(0.6) : .white.opacity(0.14), lineWidth: 1)
        )
    }

    /// The "בוצעו היום 🎉" section under the to-do grid.
    private var doneSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("בּוֹצְעוּ הַיּוֹם 🎉")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppSpacing.sm)
            LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                ForEach(doneChores) { chore in doneCard(chore) }
            }
        }
    }

    /// Shown when there's nothing left to do but chores WERE done today.
    private var allDoneBanner: some View {
        VStack(spacing: 8) {
            Text("🎉").font(.system(size: 46))
            Text(Gendered.g("כָּל הַכָּבוֹד! סִיַּמְתָּ הַכֹּל לְהַיּוֹם", "כָּל הַכָּבוֹד! סִיַּמְתְּ הַכֹּל לְהַיּוֹם"))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: "06D6A0").opacity(0.5), Color(hex: "48BFE3").opacity(0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private func statusCapsule(_ text: String, background: some ShapeStyle) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
    }

    private func rewardLine(_ c: Chore) -> String {
        "🎮 \(max(c.rewardMinutes, 0)) דַּקּוֹת מִשְׂחָק"
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
            let result = await choreStore.markDone(chore, reward: reward, photo: photo)
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
