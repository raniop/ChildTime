import SwiftUI

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
    @State private var justSent: Set<String> = []

    private var myChores: [Chore] {
        guard let id = profiles.activeID else { return [] }
        return choreStore.chores(forChild: id)
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        if progress.moneyCoins > 0 { moneyPocketCard }
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
                    Button("⏰ \(chore.rewardMinutes) דַּקּוֹת מִשְׂחָק") { send(chore, reward: "minutes") }
                }
                if chore.rewardCoins > 0 {
                    Button("🪙 \(chore.rewardCoins) שְׁקָלִים לַקֻּפָּה") { send(chore, reward: "coins") }
                }
                Button("רֶגַע, עוֹד לֹא", role: .cancel) { choosingFor = nil }
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

    /// 🪙 the kid's money pocket — what mom/dad still owe in real life.
    private var moneyPocketCard: some View {
        HStack(spacing: AppSpacing.md) {
            Text("🪙").font(.system(size: 34))
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(progress.moneyCoins) שְׁקָלִים בַּקֻּפָּה!")
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

    private func send(_ chore: Chore, reward: String) {
        choreStore.markDone(chore, reward: reward)
        justSent.insert(chore.id)
        Haptic.success()
        SoundPlayer.shared.play(.portalAppear)
        choosingFor = nil
    }
}
