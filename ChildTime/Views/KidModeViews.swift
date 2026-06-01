import SwiftUI
import FamilyControls

/// Entry flow for Kid Mode: pick which child, choose the approved apps (a list
/// separate from each child's normal device), then lock the parent's phone.
struct KidModeEntryView: View {
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var kidMode = KidModeManager.shared
    @ObservedObject private var shields = ShieldManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedChild: UUID?
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var requesting = false
    @State private var authFailed = false

    private var allowedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        childPicker
                        allowedAppsCard
                        explainer
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
                startButton
                    .padding(AppSpacing.lg)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, new in
            kidMode.allowedData = SelectionStorage.encode(new)
        }
        .onAppear {
            selection = kidMode.allowedSelection
            selectedChild = selectedChild ?? profiles.activeID ?? profiles.profiles.first?.id
        }
        .alert("צָרִיךְ הַרְשָׁאַת Screen Time", isPresented: $authFailed) {
            Button("הֲבַנְתִּי", role: .cancel) {}
        } message: {
            Text("כְּדֵי לִנְעֹל אֶת הַטֶּלֶפוֹן בְּמַצַּב יֶלֶד צָרִיךְ לְאַשֵּׁר Screen Time בִּשְׁבִיל טוֹפִי.")
        }
    }

    private var header: some View {
        ZStack {
            Text("מַצַּב יֶלֶד")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var childPicker: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("מִי מְשַׂחֵק?")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(profiles.profiles) { p in
                        Button { selectedChild = p.id } label: {
                            VStack(spacing: 6) {
                                ProfileAvatarView(profile: p, size: 64)
                                    .overlay(
                                        Circle().stroke(AppColor.starGold,
                                                        lineWidth: selectedChild == p.id ? 3 : 0)
                                    )
                                Text(p.name)
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(selectedChild == p.id ? 1 : 0.6)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var allowedAppsCard: some View {
        Button { showPicker = true } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AppColor.successMint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("אַפְּלִיקַצְיוֹת מֻתָּרוֹת")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(allowedCount == 0 ? "רַק טוֹפִי — הַקֵּשׁ לִבְחֹר עוֹד"
                                           : "\(allowedCount) אַפְּלִיקַצְיוֹת + טוֹפִי")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.left").foregroundStyle(.white.opacity(0.6))
            }
            .padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    private var explainer: some View {
        Text("כָּל שְׁאָר הָאַפְּלִיקַצְיוֹת בַּטֶּלֶפוֹן יִנָּעֲלוּ. הַיֶּלֶד יִלְמַד וְיְשַׂחֵק בְּטוֹפִי, וְכֻלָּם יוּכַל לִפְתֹּחַ אֶת הַמֻּתָּרוֹת. לִיצִיאָה — קוֹד הוֹרֶה.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
    }

    private var startButton: some View {
        Button {
            guard let child = selectedChild else { return }
            requesting = true
            Task {
                await shields.requestAuthorizationIfNeeded()
                requesting = false
                guard shields.isAuthorized else { authFailed = true; return }
                kidMode.enter(childID: child)
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if requesting { ProgressView().tint(.white) }
                Image(systemName: "lock.fill")
                Text("הַתְחֵל מַצַּב יֶלֶד")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppGradient.gold, in: Capsule())
            .glow(AppColor.starGold, radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(selectedChild == nil || requesting)
        .opacity(selectedChild == nil ? 0.5 : 1)
    }
}

/// Shown after the parent passes the PIN gate, to confirm leaving Kid Mode.
struct KidModeExitView: View {
    var onExit: () -> Void

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: AppSpacing.lg) {
                Text("🔓").font(.system(size: 72))
                Text("לָצֵאת מִמַּצַּב יֶלֶד?")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("הַטֶּלֶפוֹן יַחֲזֹר לְמַצָּב רָגִיל וְהַנְּעִילָה תּוּסַר.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button { onExit() } label: {
                    Text("כֵּן, צֵא")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppGradient.success, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 420)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
