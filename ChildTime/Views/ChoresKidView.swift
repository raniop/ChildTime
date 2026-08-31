import SwiftUI
import PhotosUI

/// 🧹 The kid's chores screen: the parent defined the chores, the kid does one,
/// taps "עשיתי!" and CHOOSES the reward — ⏰ play minutes or 🪙 money. The
/// reward lands only after the parent approves. No failure language anywhere:
/// a returned chore just shows up as available again.
struct ChoresKidView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var choreStore = ChoreStore.shared
    let onClose: () -> Void

    /// The chore the kid just tapped "עשיתי" on — reward picker is showing.
    @State private var choosingFor: Chore?
    /// Reward picked → offering an optional 📸 proof photo before sending.
    @State private var pendingSend: (chore: Chore, reward: String)?
    @State private var showPhotoOffer = false
    @State private var showCamera = false
    @State private var libraryPickerPresented = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var justSent: Set<String> = []

    private var myChores: [Chore] {
        guard let id = profiles.activeID else { return [] }
        return choreStore.chores(forChild: id)
    }

    /// 🪙 unpaid balance from the increment-only ledger (earned − paid).
    private var moneyBalance: Int {
        profiles.activeID.map { choreStore.moneyBalance(forChild: $0) } ?? 0
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
                        if moneyBalance > 0 { moneyPocketCard }
                        if myChores.isEmpty {
                            emptyState
                        } else {
                            // 2 across on iPhone, 3 on iPad (Rani).
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md),
                                                     count: hSize == .regular ? 3 : 2),
                                      spacing: AppSpacing.md) {
                                ForEach(myChores) { chore in
                                    choreCard(chore)
                                }
                            }
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
        .confirmationDialog("אֵיזֶה פְּרָס מַגִּיעַ לְךָ?", isPresented: Binding(
            get: { choosingFor != nil },
            set: { if !$0 { choosingFor = nil } }
        ), titleVisibility: .visible) {
            if let chore = choosingFor {
                if chore.rewardMinutes > 0 {
                    Button("⏰ \(chore.rewardMinutes) דַּקּוֹת מִשְׂחָק") { offerPhoto(chore, reward: "minutes") }
                }
                if chore.rewardCoins > 0 {
                    Button("🪙 \(chore.rewardCoins) שְׁקָלִים לַקֻּפָּה") { offerPhoto(chore, reward: "coins") }
                }
                Button("רֶגַע, עוֹד לֹא", role: .cancel) { choosingFor = nil }
            }
        }
        // 📸 Optional proof photo — a picture beats a debate about whether the
        // room is really tidy (Rani).
        .confirmationDialog("רוֹצִים לְצָרֵף תְּמוּנָה שֶׁל מָה שֶׁעֲשִׂיתֶם? 📸", isPresented: $showPhotoOffer,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("📸 לְצַלֵּם עַכְשָׁיו") { showCamera = true }
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
        if totals.minutes > 0 || totals.coins > 0 {
            HStack(spacing: AppSpacing.md) {
                Text("🏆").font(.system(size: 30))
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Gendered.g("סַךְ הַכֹּל הִרְוַחְתָּ מִמַּטְלוֹת:", "סַךְ הַכֹּל הִרְוַחְתְּ מִמַּטְלוֹת:"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 8) {
                        if totals.minutes > 0 {
                            Text("⏰ \(totals.minutes) דַּקּוֹת")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        if totals.minutes > 0 && totals.coins > 0 {
                            Text("·").foregroundStyle(.white.opacity(0.6))
                        }
                        if totals.coins > 0 {
                            Text("🪙 \(totals.coins) שְׁקָלִים")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
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

    /// 🪙 the kid's money pocket — what mom/dad still owe in real life.
    private var moneyPocketCard: some View {
        HStack(spacing: AppSpacing.md) {
            Text("🪙").font(.system(size: 34))
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(moneyBalance) שְׁקָלִים בַּקֻּפָּה!")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("אַבָּא אוֹ אִמָּא יִתְּנוּ לְךָ בַּיָּד 💛")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            LinearGradient(colors: [Color(hex: "F4A261"), Color(hex: "E9C46A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
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

    @ViewBuilder
    private func choreCard(_ chore: Chore) -> some View {
        VStack(spacing: 8) {
            Text(chore.emoji).font(.system(size: 38))
            Text(chore.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(minHeight: 38)
            HStack(spacing: 4) {
                if chore.rewardMinutes > 0 {
                    rewardChip("⏰ \(chore.rewardMinutes) דַּק׳")
                }
                if chore.rewardMinutes > 0 && chore.rewardCoins > 0 {
                    Text("אוֹ")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                if chore.rewardCoins > 0 {
                    rewardChip("🪙 ₪\(chore.rewardCoins)")
                }
                if chore.timesPerDay > 1 {
                    rewardChip("\(chore.doneToday)/\(chore.timesPerDay) הַיּוֹם")
                }
            }

            if chore.isPendingApproval || justSent.contains(chore.id) {
                statusCapsule("מְחַכִּים לְאִשּׁוּר 🕐", background: .white.opacity(0.16))
            } else if chore.isDaily && chore.approvedToday {
                statusCapsule(Gendered.g("סִיַּמְתָּ לְהַיּוֹם! 🏆", "סִיַּמְתְּ לְהַיּוֹם! 🏆"),
                              background: Color(hex: "06D6A0").opacity(0.45))
            } else {
                Button {
                    Haptic.success()
                    choosingFor = chore
                } label: {
                    Text("עָשִׂיתִי! ✅")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "48BFE3")],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
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

    private func rewardChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white.opacity(0.18), in: Capsule())
    }

    private func offerPhoto(_ chore: Chore, reward: String) {
        pendingSend = (chore, reward)
        choosingFor = nil
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
        choreStore.markDone(chore, reward: reward, photo: photo)
        // Latency bridge only — the listener flips isPendingApproval within a
        // beat; if we never dropped this, an APPROVED chore would keep showing
        // "מחכים לאישור" for the rest of the session.
        justSent.insert(chore.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { justSent.remove(chore.id) }
        Haptic.success()
        SoundPlayer.shared.play(.portalAppear)
        choosingFor = nil
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
