#if DEBUG
import SwiftUI

/// 🎨 Round 2 (Rani: "כל ה-4 לא התחברתי") — DEMO_DESIGN=5…7 are new full-page
/// directions, 8…10 keep today's screen and redo only the bottom.
struct QuizDesignMockup2: View {
    let variant: Int
    var body: some View {
        switch variant {
        case 6:  GameShowDesign()
        case 7:  FloatingGlassDesign()
        case 8:  CurrentWithBottom(bottom: .shelf)
        case 9:  CurrentWithBottom(bottom: .corner)
        case 10: CurrentWithBottom(bottom: .path)
        default: WorldSceneDesign()
        }
    }
}

private enum M {
    static let question = "אֵיךְ אוֹמְרִים תְּמָנוּן בְּאַנְגְּלִית?"
    static let answers = ["squid", "crab", "octopus", "fish"]
    static let correct = 2
    static func buddy(_ s: CGFloat) -> some View {
        Group {
            if let img = ProfileStore.shared.active?.character.uiImage ?? Character3DCatalog.find("fox").uiImage {
                Image(uiImage: img).resizable().scaledToFit()
            }
        }
        .frame(width: s, height: s * 1.2)
    }
    static func rr(_ fill: some ShapeStyle) -> some View { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill) }
}

private struct Icon: View {
    let name: String; var size: CGFloat = 46
    var body: some View {
        Image(systemName: name).font(.system(size: size * 0.37, weight: .bold)).foregroundStyle(.white.opacity(0.92))
            .frame(width: size, height: size).background(M.rr(.white.opacity(0.15)))
    }
}

// MARK: - 5 · Every world has its own scene (the sea here)

private struct WorldSceneDesign: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0B8FD6"), Color(hex: "0A5DA8"), Color(hex: "072F6B")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            // light rays + bubbles + seabed
            ForEach(0..<14, id: \.self) { i in
                Circle().fill(.white.opacity(0.18)).frame(width: CGFloat(6 + (i * 7) % 18))
                    .position(x: CGFloat((i * 53) % 390 + 10), y: CGFloat((i * 97) % 700 + 60))
            }
            VStack { Spacer(); Text(verbatim: "🪸  🐚      🌿   🪸     🐠").font(.system(size: 40)).opacity(0.9).padding(.bottom, 4) }.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white).frame(width: 42, height: 42).background(M.rr(.white.opacity(0.18)))
                    Spacer()
                    Text(verbatim: "🌊 מַעֲמַקֵּי הַיָּם · 7/15").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 42).background(M.rr(.white.opacity(0.18)))
                }
                .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    Text(verbatim: "🐙").font(.system(size: 80)).shadow(color: .black.opacity(0.25), radius: 10, y: 8)
                    Text(verbatim: M.question).font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "0A3D6B")).multilineTextAlignment(.center)
                }
                .padding(.vertical, 18).padding(.horizontal, 16).frame(maxWidth: .infinity)
                .background(M.rr(Color(hex: "FFF6E0")))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: "E8C77A"), lineWidth: 3))
                .padding(.horizontal, 20)

                // answers are bubbles in this world
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(M.answers.indices, id: \.self) { i in
                        let right = i == M.correct
                        Text(verbatim: M.answers[i]).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 78)
                            .background(M.rr(right ? AnyShapeStyle(Color(hex: "16C79A")) : AnyShapeStyle(.white.opacity(0.2))))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.55), lineWidth: 2))
                            .overlay(alignment: .topLeading) { Circle().fill(.white.opacity(0.7)).frame(width: 10).padding(10) }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Icon(name: "lightbulb.fill"); Icon(name: "speaker.wave.2.fill"); Icon(name: "hand.raised.fill")
                    Spacer()
                    M.buddy(78)
                }
                .padding(.horizontal, 20).padding(.bottom, 60)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 6 · TV game show — four buzzers with shapes

private struct GameShowDesign: View {
    private let colors: [Color] = [Color(hex: "E21B3C"), Color(hex: "1368CE"), Color(hex: "26890C"), Color(hex: "D89E00")]
    private let shapes = ["triangle.fill", "diamond.fill", "circle.fill", "square.fill"]
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2A0D5E"), Color(hex: "46178F")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            // stage lights
            ForEach(0..<2, id: \.self) { i in
                Ellipse().fill(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 200))
                    .frame(width: 320, height: 520).rotationEffect(.degrees(i == 0 ? 22 : -22))
                    .offset(x: i == 0 ? -120 : 120, y: -230)
            }
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white).frame(width: 42, height: 42).background(M.rr(.white.opacity(0.15)))
                    Spacer()
                    Text(verbatim: "⭐ 1.4K").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.starGold).padding(.horizontal, 12).frame(height: 42).background(M.rr(.white.opacity(0.15)))
                    Text(verbatim: "🔥 7").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 42).background(M.rr(.white.opacity(0.15)))
                }
                .padding(.horizontal, 20)
                // the host
                HStack(alignment: .center, spacing: 10) {
                    M.buddy(70)
                    Text(verbatim: "שְׁאֵלָה 7! מוּכָנִים? 🎤").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: "2A0D5E"))
                        .padding(12).background(M.rr(.white))
                    Spacer()
                }
                .padding(.horizontal, 20)
                // the big screen
                VStack(spacing: 8) {
                    Text(verbatim: "🐙").font(.system(size: 62))
                    Text(verbatim: M.question).font(.system(size: 27, weight: .heavy, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
                }
                .padding(18).frame(maxWidth: .infinity)
                .background(M.rr(Color.black.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: "FFD23F"), lineWidth: 3))
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(M.answers.indices, id: \.self) { i in
                        let right = i == M.correct
                        HStack(spacing: 10) {
                            Image(systemName: shapes[i]).font(.system(size: 22, weight: .black))
                            Text(verbatim: M.answers[i]).font(.system(size: 22, weight: .heavy, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                            if right { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)) }
                        }
                        .foregroundStyle(.white).padding(.horizontal, 16).frame(height: 96)
                        .background(ZStack { M.rr(colors[i].opacity(0.6)).offset(y: 5); M.rr(colors[i]) })
                        .opacity(right || true ? 1 : 0.4)
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(.horizontal, 16)
                HStack { Icon(name: "lightbulb.fill", size: 42); Icon(name: "speaker.wave.2.fill", size: 42); Icon(name: "hand.raised.fill", size: 42); Spacer(); Icon(name: "flag", size: 42) }
                    .padding(.horizontal, 20).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 7 · Floating glass (visionOS)

private struct FloatingGlassDesign: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FF9A8B"), Color(hex: "C56CF0"), Color(hex: "5F6BFF")], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color(hex: "FFE29A").opacity(0.55)).frame(width: 260).blur(radius: 60).offset(x: 120, y: -260)
            Circle().fill(Color(hex: "7CF6E3").opacity(0.5)).frame(width: 300).blur(radius: 70).offset(x: -140, y: 260)
            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white).frame(width: 42, height: 42).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<15, id: \.self) { i in Circle().fill(i < 7 ? .white : .white.opacity(0.35)).frame(width: i == 6 ? 10 : 6) }
                    }
                    Spacer()
                    Text(verbatim: "20:39").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 42).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Text(verbatim: "🐙").font(.system(size: 92)).shadow(color: .black.opacity(0.2), radius: 16, y: 12)
                    Text(verbatim: M.question).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .multilineTextAlignment(.center).shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(M.answers.indices, id: \.self) { i in
                        let right = i == M.correct
                        Text(verbatim: M.answers[i]).font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(right ? Color(hex: "0B5E48") : .white)
                            .frame(maxWidth: .infinity).frame(height: 80)
                            .background(right ? AnyShapeStyle(Color.white) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 10)
                    }
                }
                .padding(.horizontal, 20)
                HStack(alignment: .bottom, spacing: 12) {
                    M.buddy(64)
                    Text(verbatim: "אַלּוּפָה! 💫").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 26)
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(["lightbulb.fill", "speaker.wave.2.fill", "hand.raised.fill"], id: \.self) { n in
                            Image(systemName: n).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46)
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 8…10 · Today's screen, a new bottom

private struct CurrentWithBottom: View {
    enum Bottom { case shelf, corner, path }
    let bottom: Bottom

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 38).glassPane(radius: 16)
                    Spacer()
                    Text(verbatim: "💎 402").font(.system(size: 15, weight: .heavy, design: .rounded)).lineLimit(1).fixedSize().foregroundStyle(AppColor.diamondBlue).padding(.horizontal, 12).frame(height: 38).glassPane(radius: 16)
                    Text(verbatim: "⭐ 678").font(.system(size: 15, weight: .heavy, design: .rounded)).lineLimit(1).fixedSize().foregroundStyle(AppColor.starGold).padding(.horizontal, 12).frame(height: 38).glassPane(radius: 16)
                    Text(verbatim: "🇬🇧 שְׁאֵלָה 7/15").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1).fixedSize().padding(.horizontal, 12).frame(height: 38).glassPane(radius: 16)
                }
                .padding(.horizontal, 20)
                HStack { Text(verbatim: "⏱ 41:12 דַּק׳ לְשַׂחֵק").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white); Spacer() }
                    .padding(.horizontal, 16).frame(height: 40).glassPane(radius: 16).padding(.horizontal, 20)
                VStack(spacing: 8) {
                    Text(verbatim: "🇬🇧 אַנְגְּלִית").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    Text(verbatim: "🐙").font(.system(size: 40))
                    Text(verbatim: M.question).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
                }
                .padding(18).frame(maxWidth: .infinity).glassPane(radius: 16).padding(.horizontal, 20)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(M.answers.indices, id: \.self) { i in
                        let right = i == M.correct
                        Text(verbatim: M.answers[i]).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 84)
                            .background(M.rr(right ? AnyShapeStyle(AppColor.successMint.opacity(0.85)) : AnyShapeStyle(.white.opacity(0.14))))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(right ? 0.7 : 0.25), lineWidth: right ? 2 : 1))
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
                switch bottom {
                case .shelf:  shelf
                case .corner: corner
                case .path:   path
                }
            }
            .padding(.top, 8)
        }
    }

    /// 8 · one glass shelf: the streak meter, the per-answer seconds, the hint and
    /// the tools together; the buddy stands on its edge and talks above it.
    private var shelf: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                Spacer()
                Text(verbatim: "יָפֶה! עוֹד 3 לַקֻּפְסָה 🎁").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                    .padding(.horizontal, 12).padding(.vertical, 8).background(M.rr(.white)).padding(.bottom, 34)
                M.buddy(70)
            }
            .padding(.horizontal, 24).padding(.bottom, -2)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(verbatim: "🔥 7 בָּרֶצֶף").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white).fixedSize()
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            M.rr(.white.opacity(0.18))
                            M.rr(LinearGradient(colors: [Color(hex: "FFB347"), Color(hex: "FF5E62")], startPoint: .leading, endPoint: .trailing)).frame(width: g.size.width * 0.7)
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    .frame(height: 12)
                    // What each right answer pays — a solid chip, readable on any glass.
                    Text(verbatim: "+24 שְׁנִיּוֹת").font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "053D2E")).lineLimit(1).fixedSize()
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(M.rr(AppColor.successMint))
                }
                HStack(spacing: 10) {
                    Icon(name: "flag"); Icon(name: "speaker.wave.2.fill"); Icon(name: "hand.raised.fill")
                    Spacer()
                    HStack(spacing: 6) { Text(verbatim: "💡"); Text(verbatim: "רֶמֶז").font(.system(size: 16, weight: .heavy, design: .rounded)) }
                        .foregroundStyle(Color(hex: "3A2A00")).padding(.horizontal, 16).frame(height: 46).background(M.rr(AppGradient.gold))
                }
            }
            .padding(14).glassPane(radius: 16)
            .padding(.horizontal, 16).padding(.bottom, 6)
        }
    }

    /// 9 · the buddy owns the bottom corner and speaks beside itself; the tools
    /// sit as one segmented glass control, the streak as a flame chip.
    private var corner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: "🔥 7 בָּרֶצֶף").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.starGold)
                    .padding(.horizontal, 12).frame(height: 34).glassPane(radius: 16)
                Text(verbatim: "+24 שְׁנִ׳ לְכָל נְכוֹנָה").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12).frame(height: 34).glassPane(radius: 16)
                Spacer()
            }
            .padding(.horizontal, 20)
            HStack(alignment: .bottom, spacing: 10) {
                M.buddy(96)
                Text(verbatim: "אַלּוּפָה! מַמְשִׁיכִים 💪").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                    .padding(12).background(M.rr(.white)).padding(.bottom, 44)
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    HStack(spacing: 6) { Text(verbatim: "💡"); Text(verbatim: "רֶמֶז").font(.system(size: 15, weight: .heavy, design: .rounded)) }
                        .foregroundStyle(Color(hex: "3A2A00")).frame(width: 138, height: 44).background(M.rr(AppGradient.gold))
                    HStack(spacing: 0) {
                        ForEach(["hand.raised.fill", "speaker.wave.2.fill", "flag"], id: \.self) { n in
                            Image(systemName: n).font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 44)
                        }
                    }
                    .glassPane(radius: 16)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 6)
        }
    }

    /// 10 · a path of 15 stones: the buddy stands on the current one and steps
    /// forward with every right answer — the bottom becomes the journey.
    private var path: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Icon(name: "flag"); Icon(name: "speaker.wave.2.fill"); Icon(name: "hand.raised.fill")
                Spacer()
                HStack(spacing: 6) { Text(verbatim: "💡"); Text(verbatim: "רֶמֶז").font(.system(size: 16, weight: .heavy, design: .rounded)) }
                    .foregroundStyle(Color(hex: "3A2A00")).padding(.horizontal, 16).frame(height: 46).background(M.rr(AppGradient.gold))
            }
            .padding(.horizontal, 20)
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(0..<15, id: \.self) { i in
                        ZStack {
                            if i < 14 { Rectangle().fill(.white.opacity(i < 6 ? 0.8 : 0.25)).frame(height: 3).offset(x: 11) }
                            M.rr(i < 7 ? AnyShapeStyle(AppColor.successMint) : AnyShapeStyle(.white.opacity(0.25)))
                                .frame(width: i == 14 ? 26 : 16, height: i == 14 ? 26 : 16)
                                .overlay { if i == 14 { Text(verbatim: "🎁").font(.system(size: 15)) } }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.bottom, 6)
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(verbatim: "עוֹד 8 לַקֻּפְסָה!").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                            .padding(.horizontal, 10).padding(.vertical, 6).background(M.rr(.white))
                        M.buddy(56)
                    }
                    .padding(.trailing, 150)
                    .padding(.bottom, 14)
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 16)
            .glassPane(radius: 16)
            .padding(.horizontal, 16).padding(.bottom, 6)
        }
    }
}
#endif
