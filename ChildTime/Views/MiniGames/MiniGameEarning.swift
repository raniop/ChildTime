import SwiftUI
import Combine

// MARK: - ⏱ Earning screen time from a game

/// A game opened from a world's chooser earns screen time exactly like the
/// regular questions (Rani, 2026-10-03): every right answer goes through the
/// SAME `ProgressStore.recordCorrect` the runner uses — the parent's minutes
/// per answer, the bonus cycle, the topic balance and the daily cap all hold —
/// and a miss is `recordWrong` (half a step off the cycle, gently shown).
///
/// No game may be a cheap farm. A round of balloons can produce a "right
/// answer" every second, a regular question takes a fast child 4–6 seconds
/// (the answer + the runner's 1.5s celebration). So credits come from a token
/// bucket: one every `secondsPerCredit` of play, at most `capacity` banked,
/// `startTokens` at the start. Answers beyond that still count in the parent's
/// reports and the adaptive engine sees them — they just don't pay minutes.
///
/// ⚡ Surprise rounds never get one of these: they pay ⭐/💎 only.
@MainActor
final class MiniGameEarnSession: ObservableObject {
    /// 10 credited answers a minute at most — a fast child's pace in the runner.
    static let secondsPerCredit: Double = 6
    static let capacity: Double = 4
    static let startTokens: Double = 3

    let world: World
    @Published private(set) var flashText: String?
    @Published private(set) var flashPositive = true
    @Published private(set) var flashID = 0
    @Published private(set) var popupMinutes = 0
    @Published private(set) var showPopup = false
    @Published private(set) var capReached = false

    private var tokens = MiniGameEarnSession.startTokens
    private var lastRefill = Date()

    init(world: World) {
        self.world = world
        // The runner's session start, so the parent sees the sitting.
        let progress = ProgressStore.shared
        progress.registerSessionToday()
        LearningHistoryStore.shared.recordSessionStart(purpose: .earnTime)
        progress.beginSitting()
        if ParentSettings.shared.deviceRole == .child, let cid = ProfileStore.shared.activeID {
            Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
        }
    }

    /// Spend one credit if the pace allows it.
    func takeCredit() -> Bool {
        let now = Date()
        tokens = min(Self.capacity, tokens + now.timeIntervalSince(lastRefill) / Self.secondsPerCredit)
        lastRefill = now
        guard tokens >= 1 else { return false }
        tokens -= 1
        return true
    }

    func flash(_ text: String, positive: Bool) {
        flashPositive = positive
        flashID += 1
        let id = flashID
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { flashText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.flashID == id else { return }
            withAnimation(.easeOut(duration: 0.4)) { self.flashText = nil }
        }
    }

    func popMinutes(_ minutes: Int) {
        popupMinutes = minutes
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { showPopup = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) { self?.showPopup = false }
        }
    }

    func noteCap() { capReached = true }
}

/// The one place a game reports an answer.
enum MiniGameLedger {
    /// One answer: a right one (`correct`) or a miss, in `topic`.
    ///
    /// - From a chooser (`earn` set, not a surprise): the runner's own path —
    ///   minutes, cycle, cap, adaptive level, ⭐/💎 per answer.
    /// - Otherwise (a surprise round): counted for the parent's reports only;
    ///   the game pays its ⭐/💎 at the end.
    @MainActor
    static func record(correct: Bool, topic: Topic, responseMs: Double = 0, streak: Int = 0,
                       earn: MiniGameEarnSession?, surprise: Bool) {
        let progress = ProgressStore.shared
        guard let earn, !surprise else {
            progress.recordGameAnswer(correct: correct)
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: correct, responseMs: responseMs,
                                                     earnedMinutes: 0, streak: streak)
            return
        }
        let settings = ParentSettings.shared
        if correct {
            guard earn.takeCredit() else {
                // Faster than any child answers regular questions: counted, unpaid.
                progress.recordGameAnswer(correct: true)
                LearningHistoryStore.shared.recordAnswer(topic: topic, correct: true, responseMs: responseMs,
                                                         earnedMinutes: 0, streak: streak)
                return
            }
            let cappedBefore = progress.atDailyCap
            let minutesBefore = progress.pendingMinutes
            progress.recordCorrect(
                ProgressStore.AnswerContext(topic: topic, combo: progress.currentStreak,
                                            isSuperQuestion: false, isMysteryPortal: false),
                minutesPerCorrect: settings.minutesPerCorrectAnswer,
                responseMs: responseMs,
                grantsScreenTime: true)
            let minutesGranted = max(0, progress.pendingMinutes - minutesBefore)
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: true, responseMs: responseMs,
                                                     earnedMinutes: minutesGranted,
                                                     streak: progress.currentStreak, voluntary: cappedBefore)
            // The runner's one-shot companion flags — no companion here, so they
            // are spent now rather than surfacing late in the next session.
            progress.varietyBonusJustEarned = 0
            progress.topicBalanceNudgeTopic = nil
            progress.lastRecoveredMinutes = 0
            progress.newStreakRecord = false
            if !cappedBefore {
                earn.flash(tr("+\(progress.secondsPerCorrect) שְׁנִיּוֹת"), positive: true)
            }
            if minutesGranted > 0 { earn.popMinutes(minutesGranted) }
            if progress.atDailyCap { earn.noteCap() }
        } else {
            let lost = progress.recordWrong(topic: topic, minutesPerCorrect: settings.minutesPerCorrectAnswer,
                                            grantsScreenTime: true)
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: false, responseMs: 0,
                                                     earnedMinutes: 0, streak: 0)
            if lost > 0 { earn.flash(tr("−\(lost) שְׁנִיּוֹת · כִּמְעַט!"), positive: false) }
        }
    }
}

/// "+24 שְׁנִיּוֹת" rising toward the bar, and the "+4 דקות" pop — the runner's.
struct MiniGameEarnOverlay: View {
    @ObservedObject var earn: MiniGameEarnSession

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                EarnedMinutesPopup(minutes: earn.popupMinutes, visible: earn.showPopup)
                Spacer().frame(maxHeight: .infinity)
            }
            if let text = earn.flashText {
                Text(text)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill((earn.flashPositive ? AppColor.successMint : AppColor.flameOrange).opacity(0.95)))
                    .glow(earn.flashPositive ? AppColor.successMint : AppColor.flameOrange, radius: 10)
                    .id(earn.flashID)
                    .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
                    .padding(.top, 104)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The runner's earned-time bar: seconds toward the next bonus.
struct MiniGameEarnBar: View {
    @ObservedObject private var progress = ProgressStore.shared

    var body: some View {
        let target = progress.bonusTargetSeconds
        let secs = min(target, Int(progress.cycleSeconds.rounded()))
        let frac = target > 0 ? min(1, Double(secs) / Double(target)) : 0
        HStack(spacing: 10) {
            Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "FF9F1C")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * frac))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress.cycleSeconds)
                }
            }
            .frame(height: 7)
            Text(tr("+\(secs) שְׁנִ׳"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .glassPane(radius: 14, shadow: false)
    }
}

// MARK: - Shared pieces for the newer games

/// A short multiple-choice card (2048's bonus question, the vault's keys):
/// the question in the runner's card, answers as glass tiles. A miss glows
/// soft warm and the right tile lights mint — then `onDone(rightFirstTime)`.
struct MiniGameQuestionCard: View {
    let item: GameItem
    var header: String
    var onDone: (Bool) -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var options: [String] = []
    @State private var picked: String?
    @State private var shake: CGFloat = 0
    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        VStack(spacing: 12) {
            Text(header)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
            Text(MiniGameText.show(item.prompt))
                .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .mathLTR(MiniGameText.isMath(item.prompt))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { i, opt in
                    Button { pick(opt) } label: {
                        Text(MiniGameText.show(opt))
                            .font(.system(size: isCompact ? 19 : 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: isCompact ? 54 : 70)
                            .padding(.horizontal, 6)
                            .miniGameTile(state(of: opt), tint: OptionCard.tints[i % OptionCard.tints.count], radius: 18)
                            .mathLTR(MiniGameText.isMath(opt))
                    }
                    .buttonStyle(.juicy)
                    .disabled(picked != nil)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 560)
        .glassPane(radius: 24)
        .modifier(MiniGameShake(animatableData: shake))
        .onAppear { if options.isEmpty { options = item.shuffledOptions } }
    }

    private func state(of opt: String) -> MiniGameTileState {
        guard let picked else { return .normal }
        if opt == item.answer { return .correct }
        return opt == picked ? .wrong : .normal
    }

    private func pick(_ opt: String) {
        guard picked == nil else { return }
        let right = opt == item.answer
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { picked = opt }
        if right {
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
        } else {
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (right ? 0.7 : 1.3)) { onDone(right) }
    }
}

/// A number pad laid out left-to-right in every language: 1–9, then ⌫ 0 and
/// (when `decimal`) a point. `onKey` gets "0"…"9", "." or "⌫".
struct MiniGameNumberPad: View {
    var decimal: Bool = false
    var keyHeight: CGFloat = 52
    var onKey: (String) -> Void

    var body: some View {
        let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [decimal ? "." : "", "0", "⌫"]]
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(maxWidth: .infinity, minHeight: keyHeight)
                        } else {
                            Button {
                                Haptic.light()
                                onKey(key)
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.left.fill").font(.system(size: keyHeight * 0.36, weight: .bold))
                                    } else {
                                        Text(key).font(.system(size: keyHeight * 0.46, weight: .heavy, design: .rounded))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: keyHeight)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14)))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                            }
                            .buttonStyle(.juicy)
                            .accessibilityLabel(key == "⌫" ? tr("מְחִיקָה") : key)
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// The amount typed on a pad, shown big in a glass well (left-to-right).
struct MiniGameAnswerWell: View {
    let text: String
    var state: MiniGameTileState = .normal
    var suffix: String = ""
    var prefix: String = ""
    var height: CGFloat = 60

    var body: some View {
        Text(MiniGameText.ltr(prefix + (text.isEmpty ? "?" : text) + suffix))
            .font(.system(size: height * 0.5, weight: .black, design: .rounded))
            .foregroundStyle(text.isEmpty ? .white.opacity(0.5) : .white)
            .monospacedDigit()
            .frame(minWidth: 140, minHeight: height)
            .padding(.horizontal, 18)
            .miniGameTile(state, tint: AppColor.starGold, radius: 18)
            .mathLTR()
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
    }
}
