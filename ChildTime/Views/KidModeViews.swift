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
    /// 🧒 Opened from a child's card → that child is chosen AND Kid Mode starts
    /// on its own. A parent who pressed "לשחק כאן" on Dan's card has already
    /// said which child and what they want; a picker in between is a dead step
    /// (Rani: "לשחק כאן לא מכניס ישר למצב ילד").
    private let autoStart: Bool
    @State private var didAutoStart = false
    init(preselected: UUID? = nil, autoStart: Bool = false) {
        _selectedChild = State(initialValue: preselected)
        self.autoStart = autoStart && preselected != nil
    }
    @State private var selection = SelectionStorage.empty()
    @State private var requesting = false
    @State private var authFailed = false

    private var allowedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            // 🧒 Straight from a child's card: the picker must never flash. It
            // is the same view, so it used to draw the whole chooser for a frame
            // before the auto-start took hold (Rani). A quiet hand-over instead.
            if autoStart && !authFailed {
                VStack(spacing: AppSpacing.md) {
                    ProgressView().tint(.white).scaleEffect(1.3)
                    Text(tr("מעבירים את המכשיר…"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
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
                    // 📐 The button sits outside the scroll view, so without
                    // this it ran the full 1376pt of an iPad while the card
                    // column above it stayed 480pt wide.
                    .frame(maxWidth: 480 + AppSpacing.lg * 2)
                    .frame(maxWidth: .infinity)
            }
            }
        }
        .environment(\.layoutDirection, .app)
        .tofyActivityPicker(title: PickerCopy.kidMode.title, header: PickerCopy.kidMode.header, footer: PickerCopy.kidMode.footer, isPresented: $showPicker, selection: $selection)
        .onChangeCompat(of: selection) { _, new in
            kidMode.allowedData = SelectionStorage.encode(new)
        }
        .onAppear {
            selection = kidMode.allowedSelection
            selectedChild = selectedChild ?? profiles.activeID ?? profiles.profiles.first?.id
            if autoStart, !didAutoStart { didAutoStart = true; start() }
        }
        .alert(tr("צריך הרשאת Screen Time"), isPresented: $authFailed) {
            Button(tr("הבנתי"), role: .cancel) {}
        } message: {
            Text(tr("כדי לנעול את הטלפון במצב ילד צריך לאשר Screen Time בשביל טופי."))
        }
    }

    private var header: some View {
        ZStack {
            Text(tr("מצב ילד"))
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
                        .background(.white.opacity(0.22), in: Circle()).overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                }
                .environment(\.layoutDirection, .appMirrored)
            }
            // ✕ in the corner away from the clock on the foldable.
            .awayFromBar(.trailing)
        }
        // The title fills the band beside the clock; the children start below.
        .fillsTopBand(above: DisplayProbeView.minimumTopMargin + AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var childPicker: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(tr("מי משחק?"))
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
                    Text(tr("אפליקציות מותרות"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(allowedCount == 0 ? tr("רק טופי — הקישו לבחור עוד")
                                           : tr("\(allowedCount) אפליקציות + טופי"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: AppSymbol.forwardChevron).foregroundStyle(.white.opacity(0.6))
            }
            .padding(AppSpacing.md)
            .glassPane(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private var explainer: some View {
        Text(tr("כל שאר האפליקציות בטלפון יינעלו. הילד ילמד וישחק בטופי, ויוכל לפתוח את האפליקציות המותרות. ליציאה — קוד הורה."))
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
    }

    /// Ask for the lock, then hand the device over. Shared by the button and by
    /// the card's "לשחק כאן", which skips straight to it.
    private func start() {
        guard let child = selectedChild, !requesting else { return }
        requesting = true
        Task {
            await shields.requestAuthorizationIfNeeded(userInitiated: true)
            guard shields.isAuthorized else { requesting = false; authFailed = true; return }
            await kidMode.enter(childID: child)
            requesting = false
            dismiss()
        }
    }

    private var startButton: some View {
        Button { start() } label: {
            HStack(spacing: 8) {
                if requesting { ProgressView().tint(.white) }
                Image(systemName: "lock.fill")
                Text(tr("התחילו מצב ילד"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassFill(AppGradient.gold, radius: 30)
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
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.lg) {
                Text("🔓").font(.system(size: 72))
                Text(tr("לצאת ממצב ילד?"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr("הטלפון יחזור למצב רגיל והנעילה תוסר."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button { onExit() } label: {
                    Text(tr("כן, צאו"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.success, radius: 30)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 420)
        }
        .environment(\.layoutDirection, .app)
    }
}
