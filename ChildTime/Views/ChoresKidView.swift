import SwiftUI

/// 🧹 The kid's chores screen: the parent defined the chores, the kid does one,
/// taps "עשיתי!" and CHOOSES the reward — ⏰ play minutes or 🪙 money. The
/// reward lands only after the parent approves. No failure language anywhere:
/// a returned chore just shows up as available again.
struct ChoresKidView: View {
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var progress: ProgressStore
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
                            ForEach(myChores) { chore in
                                choreCard(chore)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.lg)
                    .frame(maxWidth: 560)
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
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Text(chore.emoji).font(.system(size: 40))
                VStack(alignment: .trailing, spacing: 4) {
                    Text(chore.title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        if chore.rewardMinutes > 0 {
                            rewardChip("⏰ \(chore.rewardMinutes) דַּק׳")
                        }
                        if chore.rewardMinutes > 0 && chore.rewardCoins > 0 {
                            Text("אוֹ")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        if chore.rewardCoins > 0 {
                            rewardChip("🪙 \(chore.rewardCoins) ₪")
                        }
                        if chore.isDaily {
                            rewardChip("כָּל יוֹם 🔁")
                        }
                    }
                }
                Spacer()
            }

            if chore.isPendingApproval || justSent.contains(chore.id) {
                Label("מְחַכִּים לְאִשּׁוּר שֶׁל אַבָּא אוֹ אִמָּא 🕐", systemImage: "hourglass")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.16), in: Capsule())
            } else if chore.isDaily && chore.approvedToday {
                Label(Gendered.g("סִיַּמְתָּ לְהַיּוֹם — אַלּוּף! 🏆", "סִיַּמְתְּ לְהַיּוֹם — אַלּוּפָה! 🏆"),
                      systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "06D6A0").opacity(0.45), in: Capsule())
            } else {
                Button {
                    Haptic.success()
                    choosingFor = chore
                } label: {
                    Text("עָשִׂיתִי! ✅")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "48BFE3")],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func rewardChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
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
