#if DEBUG
import SwiftUI

/// 🎨 DEMO_SCREEN=quizdesign DEMO_DESIGN=1…4 — four full-page directions for
/// the multiple-choice screen, drawn with the app's real glass, fonts and the
/// child's own character, for Rani to choose from (2026-10-09). Static: no
/// game logic, nothing written anywhere.
struct QuizDesignMockup: View {
    let variant: Int

    var body: some View {
        switch variant {
        case 2:  CardStackDesign()
        case 3:  RingsDesign()
        case 4:  ChatDesign()
        default: IslandDesign()
        }
    }
}

// MARK: - Shared sample content

private enum Mock {
    static let topic = "אַנְגְּלִית"
    static let question = "אֵיךְ אוֹמְרִים תְּמָנוּן בְּאַנְגְּלִית?"
    static let emoji = "🐙"
    static let answers = ["squid", "crab", "octopus", "fish"]
    static let correct = 2
    static var buddy: UIImage? {
        ProfileStore.shared.active?.character.uiImage ?? Character3DCatalog.find("fox").uiImage
    }
    static func avatar(_ size: CGFloat) -> some View {
        Group {
            if let img = buddy { Image(uiImage: img).resizable().scaledToFit() } else { Text(verbatim: "🦊").font(.system(size: size * 0.7)) }
        }
        .frame(width: size, height: size)
    }
}

private struct ToolIcon: View {
    let name: String
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 46, height: 46)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
    }
}

private struct HintPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "💡")
            Text(verbatim: "רֶמֶז").font(.system(size: 16, weight: .heavy, design: .rounded))
            Text(verbatim: "12 שְׁנִיּוֹת").font(.system(size: 13, weight: .semibold, design: .rounded)).opacity(0.75)
        }
        .foregroundStyle(Color(hex: "3A2A00"))
        .padding(.horizontal, 14).frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
    }
}

// MARK: - 1 · Dynamic Island

private struct IslandDesign: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A1446"), Color(hex: "2D1F6E"), Color(hex: "3B2A8C")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                // The buddy lives in the island and speaks from it.
                HStack(spacing: 10) {
                    Mock.avatar(34)
                    Text(verbatim: "יָפֶה! עוֹד 3 לַקֻּפְסָה 🎁")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Text(verbatim: "+24 שְׁנִ׳").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.successMint)
                }
                .padding(.horizontal, 14).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black))
                .padding(.horizontal, 30)

                HStack(spacing: 4) {
                    ForEach(0..<15, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2).fill(i < 7 ? .white : .white.opacity(0.22)).frame(height: 4)
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    Text(verbatim: "🇬🇧 \(Mock.topic) · שְׁאֵלָה 7")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    Text(Mock.emoji).font(.system(size: 64))
                    Text(Mock.question)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20).padding(.top, 8)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    ForEach(Mock.answers.indices, id: \.self) { i in
                        let right = i == Mock.correct
                        HStack {
                            Text(Mock.answers[i]).font(.system(size: 24, weight: .heavy, design: .rounded))
                            Spacer()
                            if right { Image(systemName: "checkmark").font(.system(size: 20, weight: .black)) }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).frame(height: 62)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(right ? AnyShapeStyle(AppColor.successMint) : AnyShapeStyle(.white.opacity(0.10))))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(right ? 0.5 : 0.16), lineWidth: 1))
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    HintPill()
                    Spacer()
                    ToolIcon(name: "hand.raised.fill")
                    ToolIcon(name: "speaker.wave.2.fill")
                    ToolIcon(name: "flag")
                }
                .padding(.horizontal, 20).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 2 · Card stack (Wallet)

private struct CardStackDesign: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 42, height: 42).glassPane(radius: 16)
                    Spacer()
                    Text(verbatim: "⏱ 20:39 דַּק׳ לְשַׂחֵק").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 42).glassPane(radius: 16)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    HStack {
                        Text(verbatim: "🇬🇧 \(Mock.topic)").font(.system(size: 15, weight: .heavy, design: .rounded))
                        Spacer()
                        Text(verbatim: "7 / 15").font(.system(size: 15, weight: .heavy, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(Color(hex: "5E60CE"))
                    Text(verbatim: Mock.emoji).font(.system(size: 76))
                    Text(verbatim: Mock.question)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight).multilineTextAlignment(.center)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                // The cards still to come peek out behind — the stack IS the progress.
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.6)).padding(.horizontal, 8).offset(y: -9))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.35)).padding(.horizontal, 16).offset(y: -18))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .padding(.horizontal, 20)
                .padding(.top, 18)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Mock.answers.indices, id: \.self) { i in
                        let right = i == Mock.correct
                        Text(Mock.answers[i])
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(right ? Color(hex: "0B5E48") : .white)
                            .frame(maxWidth: .infinity).frame(height: 84)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(right ? AnyShapeStyle(Color.white) : AnyShapeStyle(.white.opacity(0.16))))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(right ? AppColor.successMint : .white.opacity(0.3), lineWidth: right ? 3 : 1))
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Mock.avatar(54).offset(y: -14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "צָרִיךְ עֶזְרָה?").font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text(verbatim: "🔥 7 בָּרֶצֶף · +24 שְׁנִ׳ לְכָל נְכוֹנָה").font(.system(size: 13, weight: .semibold, design: .rounded)).opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    ToolIcon(name: "speaker.wave.2.fill")
                    ToolIcon(name: "lightbulb.fill")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassPane(radius: 16)
                .padding(.horizontal, 16).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 3 · Activity rings (Watch)

private struct Ring: View {
    let progress: Double; let color: Color; let width: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: width)
            Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))
        }
    }
}

private struct RingsDesign: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Ring(progress: 7.0 / 15, color: Color(hex: "FF4F6D"), width: 12).frame(width: 104, height: 104)
                        Ring(progress: 0.7, color: Color(hex: "A6F23A"), width: 12).frame(width: 74, height: 74)
                        Ring(progress: 0.45, color: Color(hex: "3CE0F0"), width: 12).frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "7/15 שְׁאֵלוֹת").foregroundStyle(Color(hex: "FF8FA3"))
                        Text(verbatim: "🔥 7 בָּרֶצֶף").foregroundStyle(Color(hex: "C6F77A"))
                        Text(verbatim: "+3:20 דַּק׳ הַיּוֹם").foregroundStyle(Color(hex: "8BF0FA"))
                    }
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 42, height: 42).glassPane(radius: 16)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    Text(verbatim: "🇬🇧 \(Mock.topic)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                    Text(Mock.emoji).font(.system(size: 54))
                    Text(Mock.question).font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).multilineTextAlignment(.center)
                }
                .padding(20).frame(maxWidth: .infinity)
                .glassPane(radius: 16)
                .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                    ForEach(Mock.answers.indices, id: \.self) { i in
                        let right = i == Mock.correct
                        Text(Mock.answers[i])
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 76)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(right ? Color(hex: "04A57C") : Color(hex: "3D3399")).offset(y: 6)
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(right ? AppColor.successMint : Color(hex: "6C5CE7"))
                                }
                            )
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    Mock.avatar(92)
                    Text(verbatim: "הַטַּבַּעַת הַיְּרֻקָּה כִּמְעַט נִסְגֶּרֶת! 💚")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                        .padding(.bottom, 40)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    HintPill()
                    Spacer()
                    ToolIcon(name: "hand.raised.fill")
                    ToolIcon(name: "speaker.wave.2.fill")
                    ToolIcon(name: "flag")
                }
                .padding(.horizontal, 20).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 4 · Conversation (Messages)

private struct ChatDesign: View {
    private func buddyBubble<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack { c().padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.22))); Spacer(minLength: 50) }
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 42, height: 42).glassPane(radius: 16)
                    Spacer()
                    VStack(spacing: 2) {
                        Mock.avatar(52)
                        Text(verbatim: "טוֹפִי · \(Mock.topic)").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text(verbatim: "🔥 7").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .frame(width: 58, height: 42).glassPane(radius: 16)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    buddyBubble { Text(verbatim: "מָה זֶה dog?").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white) }
                    HStack {
                        Spacer(minLength: 50)
                        Text(verbatim: "כֶּלֶב ✓").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.successMint))
                    }
                    buddyBubble { Text(verbatim: "מְעֻלֶּה! +24 שְׁנִיּוֹת 🎉").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white) }
                    buddyBubble {
                        VStack(spacing: 6) {
                            Text(Mock.emoji).font(.system(size: 56))
                            Text(Mock.question).font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                Text(verbatim: "בַּחֲרוּ תְּשׁוּבָה").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Mock.answers.indices, id: \.self) { i in
                        Text(Mock.answers[i])
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    HintPill()
                    Spacer()
                    ToolIcon(name: "hand.raised.fill")
                    ToolIcon(name: "speaker.wave.2.fill")
                    ToolIcon(name: "flag")
                }
                .padding(.horizontal, 20).padding(.bottom, 6)
            }
            .padding(.top, 8)
        }
    }
}
#endif
