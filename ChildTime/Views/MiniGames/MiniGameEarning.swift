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
    private var lastRefill: Date
    /// The bucket's clock. Real time in the app; the economy harness replaces it
    /// with a virtual one so a whole round can be replayed at any pace.
    private let clock: () -> Date

    init(world: World, clock: @escaping () -> Date = { Date() }) {
        self.world = world
        self.clock = clock
        self.lastRefill = clock()
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
        let now = clock()
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

    func noteCap() {
        guard !capReached else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { capReached = true }
    }
}

/// The one place a game reports an answer.
enum MiniGameLedger {
    /// ⏱ Screen time this round has paid, in SECONDS — the same seconds the child
    /// watches rise in the top bar ("+24 שְׁנִ׳"). The end card says what THIS round
    /// was worth (Rani, 2026-10-05: "תציג כמה דק הרוויחו בכל סיבוב"), and seconds
    /// are what a round actually pays: five answers are usually under two minutes,
    /// so counting whole minutes would have shown nothing at all.
    /// `MiniGameReward.grant` takes it once, at the round's end.
    private(set) static var roundSeconds = 0

    /// ⚡ Set by the question runner while its surprise round is on screen, when
    /// the session itself earns screen time (never in Free Learning).
    static var surpriseEarnsTime = false
    static func takeRoundSeconds() -> Int {
        defer { roundSeconds = 0 }
        return roundSeconds
    }

    /// One answer: a right one (`correct`) or a miss, in `topic`.
    ///
    /// - From a chooser (`earn` set, not a surprise): the runner's own path —
    ///   minutes, cycle, cap, adaptive level, ⭐/💎 per answer.
    /// - Otherwise: counted for the parent's reports; the game pays its ⭐/💎
    ///   at the end. ⚡ In a surprise round from an earning session a right
    ///   answer ALSO pays its seconds (`surpriseEarnsTime`), so the end card
    ///   shows ⏱ like every other round.
    ///
    /// `retry` is a right answer that came after a miss on the SAME item — the
    /// runner's re-asked question. It pays in full (Rani, 2026-10-04: a child
    /// who fixes a mistake has learnt the thing, and a card reading "⭐ +0"
    /// after a round they finished is the opposite of the truth), but it does
    /// not claim the recovery pot, which is the prize for a clean answer.
    @MainActor
    static func record(correct: Bool, topic: Topic, responseMs: Double = 0, streak: Int = 0,
                       earn: MiniGameEarnSession?, surprise: Bool, retry: Bool = false) {
        let progress = ProgressStore.shared
        guard let earn, !surprise else {
            progress.recordGameAnswer(correct: correct)
            var earnedMinutes = 0
            if correct && surprise && surpriseEarnsTime {
                let before = progress.pendingMinutes
                roundSeconds += progress.creditSurpriseAnswer(topic: topic)
                earnedMinutes = max(0, progress.pendingMinutes - before)
            }
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: correct, responseMs: responseMs,
                                                     earnedMinutes: earnedMinutes, streak: streak)
            return
        }
        let settings = ParentSettings.shared
        if correct {
            // The token bucket withholds MINUTES ONLY. An answer faster than the
            // pace still counts in the parent's reports, still teaches the
            // adaptive engine and still pays its ⭐/💎 — a child racing through a
            // board of balloons used to watch their stars stop dead.
            let paysMinutes = earn.takeCredit()
            let cappedBefore = progress.atDailyCap
            let minutesBefore = progress.pendingMinutes
            let stars = progress.recordCorrect(
                ProgressStore.AnswerContext(topic: topic, combo: progress.currentStreak,
                                            isSuperQuestion: false, isMysteryPortal: false),
                minutesPerCorrect: settings.minutesPerCorrectAnswer,
                responseMs: responseMs,
                hadMistakeThisQuestion: retry,
                grantsScreenTime: paysMinutes)
            let minutesGranted = max(0, progress.pendingMinutes - minutesBefore)
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: true, responseMs: responseMs,
                                                     earnedMinutes: minutesGranted,
                                                     streak: progress.currentStreak,
                                                     voluntary: cappedBefore || !paysMinutes)
            // The runner's one-shot companion flags — no companion here, so they
            // are spent now rather than surfacing late in the next session (the
            // variety bonus still pops its "+N דקות" below).
            let varietyBonus = progress.varietyBonusJustEarned
            progress.varietyBonusJustEarned = 0
            progress.topicBalanceNudgeTopic = nil
            progress.lastRecoveredMinutes = 0
            progress.newStreakRecord = false
            // Answering right is NEVER silent: seconds when seconds were earned,
            // the stars themselves when they weren't.
            let paid = paysMinutes ? progress.lastPaidSeconds : 0
            if paid > 0 {
                roundSeconds += paid
                earn.flash(tr("+\(paid) שְׁנִיּוֹת"), positive: true)
            } else {
                earn.flash("⭐ +\(stars)", positive: true)
            }
            // Seconds land in the wallet one answer at a time now, so only a real
            // bonus gets the big "+N דקות" pop.
            if varietyBonus > 0 { earn.popMinutes(varietyBonus) }
            if progress.atDailyCap { earn.noteCap() }
        } else {
            let lost = progress.recordWrong(topic: topic, minutesPerCorrect: settings.minutesPerCorrectAnswer,
                                            grantsScreenTime: true)
            LearningHistoryStore.shared.recordAnswer(topic: topic, correct: false, responseMs: 0,
                                                     earnedMinutes: 0, streak: 0)
            // A miss is owed by the next right answer, which then pays (and adds
            // to `roundSeconds`) that much less — so nothing to take off here,
            // and no "−12 שניות" either: just the encouraging word.
            if lost > 0 {
                earn.flash(tr("כִּמְעַט!"), positive: false)
            }
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
            // ⏰ Today's time is full. The child keeps playing and keeps earning
            // ⭐/💎 — so say that, instead of going quiet and letting it look
            // like the game stopped paying.
            if earn.capReached {
                Text(tr("אָסַפְתֶּם אֶת כָּל הַזְּמַן לְהַיּוֹם! מַמְשִׁיכִים לֶאֱסֹף כּוֹכָבִים ⭐"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(AppColor.starGold.opacity(0.9)))
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 150)   // under the top bar and under the flash
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The runner's earned-time bar: the child's REAL balance, to the second.
/// Every right answer's "+24 שניות" lands in this number (it used to be a bar
/// toward the next batch of 10, which the home screen never showed — Rani).
struct MiniGameEarnBar: View {
    var body: some View {
        EarnedBalanceRow(size: 13)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .glassPane(radius: 14, shadow: false)
    }
}

/// "⏱ 23:47 דַּקּ׳ לְשַׂחֵק" — the earned wallet, the same number the home
/// screen and "פתחו לי" show.
struct EarnedBalanceRow: View {
    @ObservedObject private var progress = ProgressStore.shared
    var size: CGFloat = 14

    var body: some View {
        let secs = progress.openableSeconds(gift: false)
        HStack(spacing: 8) {
            Image(systemName: "timer").font(.system(size: size + 1, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            Text(String(format: "%d:%02d", secs / 60, secs % 60))
                .font(.system(size: size + 3, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .environment(\.layoutDirection, .leftToRight)
                .numericTextTransition(Double(secs))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: secs)
            Text(tr("דַּקּ׳ לְשַׂחֵק"))
                .font(.system(size: size - 1, weight: .bold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, .app)
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
                            Color.clear.frame(maxWidth: .infinity).frame(height: keyHeight)
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
                                .frame(maxWidth: .infinity)
                                .frame(height: keyHeight)
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
