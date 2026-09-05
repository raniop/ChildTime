import SwiftUI

/// 🎒 September 1st — the first day of school! Shown ONCE per school year on
/// the child's device when their grade auto-advances (see
/// `Profile.effectiveGrade`). Design: Rani's chosen COMBO of the two variants
/// he reviewed — the spinning-sunburst gold medal carrying the new grade, over
/// a sky of endlessly rising balloons.
struct SchoolYearCelebrationView: View {
    let gradeName: String
    let childName: String
    var gender: ChildGender? = nil
    let onDone: () -> Void

    @State private var appeared = false
    @State private var stage = 0     // staged entrance: 0 → 3

    /// "עוֹלֶה" / "עוֹלָה" by the child's gender (the old slash-both was a bug).
    private var risesVerb: String { gender == .girl ? "עוֹלָה" : "עוֹלֶה" }

    var body: some View {
        ZStack {
            goldBackground

            VStack(spacing: AppSpacing.md) {
                Spacer(minLength: 20)

                medal

                Text("יוֹם רִאשׁוֹן לַלִּמּוּדִים!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .multilineTextAlignment(.center)
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 18)

                (Text("\(childName) ")
                    .foregroundColor(Color(hex: "FFD23F"))
                 + Text("\(risesVerb) לְ\(gradeName)!")
                    .foregroundColor(.white))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .scaleEffect(stage >= 2 ? 1 : 0.4)
                    .opacity(stage >= 2 ? 1 : 0)

                Text("שָׁנָה חֲדָשָׁה, הַרְפַּתְקָה חֲדָשָׁה — טוֹפִי כְּבָר הֵכִין\nשְׁאֵלוֹת חֲדָשׁוֹת בְּדִיּוּק \(gender == .girl ? "בִּשְׁבִילֵךְ" : "בִּשְׁבִילְךָ")! 🚀")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 ? 0 : 12)

                Spacer()

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text("יַאלְלָה, מַתְחִילִים! 🚀")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.white.opacity(0.92)))
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(stage >= 3 ? 1 : 0)
            }

        }
        .overlay {
            // 🎊 Gentle popper confetti — launched from the bottom, arcs up,
            // drifts slowly down and fades (Rani's real-confetti spec).
            FancyConfetti()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            appeared = true
            SoundPlayer.shared.play(.levelUp)
            // No confetti here (Rani) — the endlessly rising balloons ARE the
            // celebration; confetti on top was noise.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { stage = 1 }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.55)) { stage = 2 }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) { stage = 3 }
        }
    }

    // MARK: - Background: sunrise sky full of rising balloons

    private var goldBackground: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 14, size: 11)
            BalloonField(startDelay: 7)
            // (No 🎆/🎇 corner emojis — iOS renders those as framed photos.)
        }
    }

    /// Giant gold medal with the new grade, slow-spinning sunburst behind it.
    private var medal: some View {
        ZStack {
            Starburst()
                .fill(LinearGradient(colors: [Color(hex: "FFD23F").opacity(0.55), .clear],
                                     startPoint: .center, endPoint: .top))
                .frame(width: 340, height: 340)
                .rotationEffect(.degrees(appeared ? 360 : 0))
                .animation(.linear(duration: 24).repeatForever(autoreverses: false), value: appeared)

            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FFE9A3").opacity(0.55), Color(hex: "FFB347").opacity(0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 172, height: 172)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 5))
                .shadow(color: .black.opacity(0.3), radius: 14, y: 8)

            VStack(spacing: 0) {
                Text("🎒").font(.system(size: 42))
                Text(gradeName)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "6B3B00"))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 16)
            }
            .frame(width: 165)
        }
        .frame(height: 300)
        .scaleEffect(stage >= 1 ? 1 : 0.2)
        .animation(.spring(response: 0.6, dampingFraction: 0.55), value: stage)
    }

}

/// 12-ray sunburst behind the medal.
private struct Starburst: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOuter = min(rect.width, rect.height) / 2
        let rInner = rOuter * 0.22
        let rays = 12
        for i in 0..<rays {
            let a0 = (Double(i) / Double(rays)) * 2 * .pi
            let a1 = a0 + (2 * .pi / Double(rays)) * 0.45
            let mid = (a0 + a1) / 2
            p.move(to: CGPoint(x: c.x + rInner * cos(a0), y: c.y + rInner * sin(a0)))
            p.addLine(to: CGPoint(x: c.x + rOuter * cos(mid), y: c.y + rOuter * sin(mid)))
            p.addLine(to: CGPoint(x: c.x + rInner * cos(a1), y: c.y + rInner * sin(a1)))
            p.closeSubpath()
        }
        return p
    }
}

/// A loop of balloons drifting up the screen forever. `startDelay` holds the
/// whole show back — the September parties let the confetti burst play out
/// ALONE first, and only then the balloons begin (Rani's sequencing).
private struct BalloonField: View {
    var startDelay: Double = 0
    private static let balloons: [(emoji: String, x: CGFloat, size: CGFloat, duration: Double, delay: Double)] = [
        ("🎈", 0.10, 52, 7.0, 0.0), ("🎈", 0.85, 44, 8.5, 1.2),
        ("🟡", 0.30, 0,  0,   0),   // spacer entry never rendered (size 0)
        ("🎈", 0.55, 60, 6.2, 2.1), ("🎈", 0.22, 38, 9.0, 3.0),
        ("🎉", 0.72, 40, 7.6, 0.8), ("⭐️", 0.42, 30, 8.2, 2.6),
        ("🎈", 0.93, 48, 6.8, 3.6), ("🎊", 0.05, 36, 7.9, 1.9),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(Self.balloons.enumerated()), id: \.offset) { _, b in
                if b.size > 0 {
                    RisingEmoji(emoji: b.emoji, size: b.size,
                                x: geo.size.width * b.x,
                                screenH: geo.size.height,
                                duration: b.duration, delay: b.delay + startDelay)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct RisingEmoji: View {
    let emoji: String
    let size: CGFloat
    let x: CGFloat
    let screenH: CGFloat
    let duration: Double
    let delay: Double
    @State private var up = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .position(x: x, y: up ? -80 : screenH + 80)
            .animation(.linear(duration: duration).repeatForever(autoreverses: false).delay(delay), value: up)
            .onAppear { up = true }
    }
}

enum SchoolYearCelebration {
    /// The school year already celebrated (or acknowledged) for a profile.
    /// ".v2" — Sep 2026: the party was redesigned on the morning of Sep 1,
    /// AFTER some kids had already seen (and burned) the old one. The one-time
    /// migration below re-shows the new design for exactly those kids.
    private static func key(_ id: UUID) -> String { "schoolYear.celebrated.v2.\(id.uuidString)" }
    private static func legacyKey(_ id: UUID) -> String { "schoolYear.celebrated.\(id.uuidString)" }

    /// Whether to show the party for this profile now — and keep the stored
    /// year in sync. First sighting of a profile just records the current year
    /// (no fake party on day one); a real advance celebrates only during the
    /// first months of school (Sep–Oct), otherwise it's silently acknowledged.
    @MainActor
    static func shouldCelebrate(_ profile: Profile, now: Date = Date()) -> Bool {
        guard profile.grade != nil else { return false }
        let current = Profile.schoolYear(for: now)
        let d = UserDefaults.standard
        guard let stored = d.object(forKey: key(profile.id)) as? Int else {
            // MIGRATION (kill after Oct 2026): a legacy record that already
            // equals the CURRENT school year means this device celebrated on
            // the morning of Sep 1 2026 with the old design — re-run the
            // (new) party once. Any other legacy value carries over normally.
            let comps = Calendar.current.dateComponents([.year, .month], from: now)
            if let legacy = d.object(forKey: legacyKey(profile.id)) as? Int {
                d.set(current, forKey: key(profile.id))
                if legacy == current, comps.year == 2026, comps.month == 9 || comps.month == 10 {
                    return true   // Rani: everyone who saw this morning's party — reset
                }
                if current > legacy, comps.month == 9 || comps.month == 10 { return true }
                return false
            }
            d.set(current, forKey: key(profile.id))
            return false
        }
        guard current > stored else { return false }
        d.set(current, forKey: key(profile.id))
        let month = Calendar.current.component(.month, from: now)
        return month == 9 || month == 10
    }
}

// MARK: - Parent-side September greeting

/// ☀️ Full-screen September party on the PARENT device (Rani: "מסך יפה כמו
/// שיש לילדים") — same visual language as the kid celebration: sun-medal,
/// rising balloons — wishing every child a great new school year.
struct ParentSchoolYearPartyView: View {
    let profiles: [Profile]
    let onDone: () -> Void

    @State private var appeared = false
    @State private var stage = 0

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 14, size: 11)
            BalloonField(startDelay: 7)

            VStack(spacing: AppSpacing.md) {
                Spacer(minLength: 16)

                // The sun-medal — here it carries the backpack + the wish.
                ZStack {
                    Starburst()
                        .fill(LinearGradient(colors: [Color(hex: "FFD23F").opacity(0.55), .clear],
                                             startPoint: .center, endPoint: .top))
                        .frame(width: 320, height: 320)
                        .rotationEffect(.degrees(appeared ? 360 : 0))
                        .animation(.linear(duration: 24).repeatForever(autoreverses: false), value: appeared)
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "FFE9A3").opacity(0.55), Color(hex: "FFB347").opacity(0.45)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 160, height: 160)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 5))
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                    VStack(spacing: 2) {
                        Text("🎒").font(.system(size: 44))
                        Text("שָׁנָה חֲדָשָׁה!")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "6B3B00"))
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 12)
                    }
                    .frame(width: 150)
                }
                .frame(height: 280)
                .scaleEffect(stage >= 1 ? 1 : 0.2)
                .animation(.spring(response: 0.6, dampingFraction: 0.55), value: stage)

                Text("שֶׁתִּהְיֶה שְׁנַת לִמּוּדִים נִפְלָאָה!")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .multilineTextAlignment(.center)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 18)

                VStack(spacing: 6) {
                    ForEach(profiles) { p in
                        if p.grade != nil {
                            (Text("\(p.name) ")
                                .foregroundColor(Color(hex: "FFD23F"))
                             + Text("\(p.gender == .girl ? "עוֹלָה" : "עוֹלֶה") לְ\(Profile.gradeDisplayName(p.effectiveGrade))! ⭐️")
                                .foregroundColor(.white))
                                .font(.system(size: 23, weight: .black, design: .rounded))
                                .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
                                .multilineTextAlignment(.center)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .scaleEffect(stage >= 2 ? 1 : 0.4)
                .opacity(stage >= 2 ? 1 : 0)

                Text("שָׁנָה שֶׁל סַקְרָנוּת, בִּטָּחוֹן וְהָמוֹן רְגָעִים טוֹבִים —\nטוֹפִי כְּבָר מְחַכֶּה לָהֶם עִם שְׁאֵלוֹת חֲדָשׁוֹת 💛")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 ? 0 : 12)

                Spacer()

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text("לְשָׁנָה מֻצְלַחַת! 💛")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.white.opacity(0.92)))
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(stage >= 3 ? 1 : 0)
            }

        }
        .overlay {
            // 🎊 Gentle popper confetti — launched from the bottom, arcs up,
            // drifts slowly down and fades (Rani's real-confetti spec).
            FancyConfetti()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            appeared = true
            SoundPlayer.shared.play(.levelUp)
            // No confetti here (Rani) — the endlessly rising balloons ARE the
            // celebration; confetti on top was noise.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { stage = 1 }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.55)) { stage = 2 }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) { stage = 3 }
        }
    }
}

extension SchoolYearCelebration {
    private static var parentKey: String { "parentSchoolYearGreeted.\(Profile.schoolYear())" }

    /// Show the parent card through September, until dismissed.
    @MainActor
    static var shouldGreetParent: Bool {
        Calendar.current.component(.month, from: Date()) == 9
            && !UserDefaults.standard.bool(forKey: parentKey)
    }

    @MainActor
    static func markParentGreeted() {
        UserDefaults.standard.set(true, forKey: parentKey)
    }
}
