import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🎁 "אבא ואמא שלחו לך משהו חדש!" — the child's first open after a parent
/// bought a pack. Rani: kids' screens must MOVE. Two beats: a wobbling gift
/// that waits for the child's tap, then a confetti burst, the world's emoji
/// springs in and floats, the title slams in, the button pulses.
struct PackRevealView: View {
    let pack: QuestionPack
    /// true → mom and dad bought it; false → it opened with Tofy+ ("a new world arrived").
    var isGift: Bool = true
    let onStart: () -> Void
    /// ✕ / "אולי אחר כך" — the surprise is seen once, the world keeps its "חדש!" badge.
    let onSkip: () -> Void

    private enum Stage { case wrapped, opening, open }
    @State private var stage: Stage = .wrapped
    @State private var wobble = false          // gift: slow rock + breathe
    @State private var shake = false           // gift: fast shiver while opening
    @State private var halo = false            // glow pulse
    @State private var float = false           // emoji hover
    @State private var emojiScale: CGFloat = 0.1
    @State private var spin: Double = -30
    @State private var titleIn = false
    @State private var chipsIn = 0
    @State private var ctaPulse = false
    @State private var confetti = 0
    @State private var hint = false

    private var isGirl: Bool { ProfileStore.shared.active?.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 18, size: 12)
            FancyConfetti(trigger: confetti, pieces: 90)

            VStack(spacing: 14) {
                HStack {
                    Button { Haptic.light(); onSkip() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.22), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
                ZStack {
                    // Living glow behind the hero — breathes the whole time.
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "FFD23F").opacity(0.55), Color(hex: "FF7BD3").opacity(0.18), .clear],
                                             center: .center, startRadius: 10, endRadius: 190))
                        .frame(width: 380, height: 380)
                        .scaleEffect(halo ? 1.12 : 0.88)
                        .opacity(halo ? 1 : 0.7)
                    if stage != .open {
                        Text("🎁")
                            .font(.system(size: 150))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 12)
                            .rotationEffect(.degrees(shake ? 9 : (wobble ? 7 : -7)))
                            .scaleEffect(shake ? 1.18 : (wobble ? 1.06 : 0.97))
                            .offset(y: wobble ? -8 : 6)
                            .onTapGesture { open() }
                    } else {
                        Text(pack.emoji)
                            .font(.system(size: 150))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 12)
                            .scaleEffect(emojiScale)
                            .rotationEffect(.degrees(spin))
                            .offset(y: float ? -14 : 10)
                    }
                }
                .frame(height: 300)

                if stage == .open {
                    Text(pack.name)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
                        .multilineTextAlignment(.center)
                        .scaleEffect(titleIn ? 1 : 0.3)
                        .opacity(titleIn ? 1 : 0)
                    Text(isGift ? "אַבָּא וְאִמָּא שָׁלְחוּ לְךָ עוֹלָם חָדָשׁ! 🎉" : "עוֹלָם חָדָשׁ הִגִּיעַ לְטוֹפִי — וּפָתוּחַ בִּשְׁבִילְךָ! 👑")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .opacity(titleIn ? 1 : 0)
                        .offset(y: titleIn ? 0 : 16)
                    HStack(spacing: 8) {
                        chip("🧠 \(pack.questionCount) שְׁאֵלוֹת", 1)
                        chip("🏆 3 רָמוֹת", 2)
                        chip("⏱ דַּקּוֹת מִשְׂחָק", 3)
                    }
                    .padding(.top, 4)
                } else {
                    Text(isGift ? "יֵשׁ לְךָ מַתָּנָה!" : "יֵשׁ לְךָ הַפְתָּעָה!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(GlassInk.primary)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
                    Text(isGift ? "מֵאַבָּא וְאִמָּא 💝" : "עוֹלָם חָדָשׁ נִפְתַּח 🌍")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("👆 \(g("לְחַץ", "לַחֲצִי")) עַל הַמַּתָּנָה כְּדֵי לִפְתֹּחַ")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .offset(y: hint ? -4 : 4)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)

                if stage == .open {
                    Button {
                        Haptic.success()
                        SoundPlayer.shared.play(.portalAppear)
                        onStart()
                    } label: {
                        Text("יַאלְלָה, \(g("בּוֹא", "בּוֹאִי")) נְשַׂחֵק! 🚀")
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "4B3FBF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.94)))
                            .shadow(color: Color(hex: "FFD23F").opacity(ctaPulse ? 0.55 : 0.15), radius: ctaPulse ? 26 : 10, y: 8)
                    }
                    .buttonStyle(.juicy)
                    .scaleEffect(ctaPulse ? 1.04 : 0.98)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Button { Haptic.light(); onSkip() } label: {
                    Text("אוּלַי אַחַר כָּךְ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            SoundPlayer.shared.play(.portalAppear)
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { wobble = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { halo = true }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { hint = true }
        }
    }

    private func chip(_ t: String, _ order: Int) -> some View {
        Text(t)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.18)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .scaleEffect(chipsIn >= order ? 1 : 0.2)
            .opacity(chipsIn >= order ? 1 : 0)
    }

    /// The tap: shiver → burst → the world springs in.
    private func open() {
        guard stage == .wrapped else { return }
        stage = .opening
        Haptic.light()
        withAnimation(.easeInOut(duration: 0.07).repeatCount(9, autoreverses: true)) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            SoundPlayer.shared.play(.chestOpen)
            Haptic.success()
            confetti += 1
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { stage = .open }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5)) { emojiScale = 1; spin = 0 }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.7)) { float = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { titleIn = true }
                SoundPlayer.shared.play(.worldUnlock)
            }
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { chipsIn = i }
                    SoundPlayer.shared.play(.streakUp)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { ctaPulse = true }
            }
        }
    }
}

/// What a CHILD sees for a pack the family doesn't have yet — from the home
/// tile or a discovery push. No price, no store, no gate: what it is, and one
/// button that tells a parent (Kids Category), mirroring AskParentView.
struct PackAskParentView: View {
    let pack: QuestionPack
    let onClose: () -> Void
    @State private var sent = false
    @State private var sending = false

    private var child: Profile? { ProfileStore.shared.active }
    private var isGirl: Bool { child?.gender == .girl }
    private func g(_ m: String, _ f: String) -> String { isGirl ? f : m }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: 18) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.22), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
                Text(pack.emoji).font(.system(size: 72))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                Text("\(g("רוֹצֶה", "רוֹצָה")) לִלְמֹד עַל \(pack.shortSubject)?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(pack.tagline) — וְעַל כָּל תְּשׁוּבָה נְכוֹנָה מַרְוִיחִים דַּקּוֹת מִשְׂחָק ⏱")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(pack.learns, id: \.self) { line in
                        HStack(spacing: 12) {
                            Text("✓").font(.system(size: 16, weight: .heavy)).foregroundStyle(GlassInk.good)
                            Text(line).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .glassPane(radius: 22)
                Spacer(minLength: 0)
                Button {
                    guard !sent, !sending else { return }
                    Haptic.success()
                    sending = true
                    Task { await sendRequest(); sending = false; sent = true }
                } label: {
                    HStack(spacing: 10) {
                        if sending { ProgressView().tint(AppColor.textOnLight) }
                        Text(sent ? "נִשְׁלַח לְאַבָּא וּלְאִמָּא ✅" : "\(g("בַּקֵּשׁ", "בַּקְּשִׁי")) מֵאַבָּא אוֹ אִמָּא 💌")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.92)))
                    .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                }
                .buttonStyle(.juicy)
                .disabled(sent)
                Text(sent ? "הֵם יְקַבְּלוּ הוֹדָעָה בַּטֶּלֶפוֹן 📱" : "הַבַּקָּשָׁה מַגִּיעָה יָשָׁר לַטֶּלֶפוֹן שֶׁל הַהוֹרֶה")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// Stamps `packRequestedAt` + `packRequestedID` on the child doc — the
    /// parent's home shows "יואב מבקש את עולם הכדורגל" and the `onPackRequest`
    /// function pushes their phone. Confirmed write ([[command-delivery-certainty]]).
    private func sendRequest() async {
        #if canImport(FirebaseFirestore)
        guard let id = child?.id else { return }
        let ref = Firestore.firestore().collection("children").document(id.uuidString)
        _ = await confirmedMerge(ref, ["packRequestedAt": Date().timeIntervalSince1970,
                                       "packRequestedID": pack.id,
                                       "packRequestedBy": DeviceIdentity.friendlyName])
        #endif
    }
}
