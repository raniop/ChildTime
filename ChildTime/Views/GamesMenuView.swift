import SwiftUI

/// A bright, kid-friendly chooser for the mini-game modes — replaces the plain
/// system action sheet with big, colorful, tappable game cards. Owns the game
/// covers itself so the world map only needs to present this one screen.
struct GamesMenuView: View {
    var onClose: () -> Void

    @State private var showingTrueFalse = false
    @State private var showingMatch = false
    @State private var showingQuiz = false
    @State private var showingMemory = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "5B6CFF"), Color(hex: "9B5DE5"), Color(hex: "EF476F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingOrbs.home().opacity(0.5)
            SparkleField(count: 22, size: 12)

            VStack(spacing: 16) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        gameCard(
                            emoji: "⚡️",
                            title: "מֵרוֹץ נָכוֹן/לֹא נָכוֹן",
                            subtitle: "מַהֵר! נָכוֹן אוֹ לֹא? בּוֹנוּס עַל מְהִירוּת 🔥",
                            colors: [Color(hex: "EF476F"), Color(hex: "FF8A5B")]
                        ) { showingTrueFalse = true }

                        gameCard(
                            emoji: "🎯",
                            title: "חִידוֹן בָּזָק",
                            subtitle: "אַרְבַּע תְּשׁוּבוֹת — בְּחַר אֶת הַנְּכוֹנָה מַהֵר!",
                            colors: [Color(hex: "118AB2"), Color(hex: "5B6CFF")]
                        ) { showingQuiz = true }

                        gameCard(
                            emoji: "🧩",
                            title: "הַתְאָמַת זוּגוֹת",
                            subtitle: "הַתְאִימוּ שְׁאֵלָה לַתְּשׁוּבָה וְזִכּוּ בְּפַרְסִים",
                            colors: [Color(hex: "06D6A0"), Color(hex: "118AB2")]
                        ) { showingMatch = true }

                        gameCard(
                            emoji: "🧠",
                            title: "מִשְׂחַק הַזִּכָּרוֹן",
                            subtitle: "מָצְאוּ אֶת הָאֶמוֹגִ'י וְהַמִּלָּה בְּאַנְגְּלִית",
                            colors: [Color(hex: "9B5DE5"), Color(hex: "EF476F")]
                        ) { showingMemory = true }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 80)

            // Close (X)
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.2)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
        .fullScreenCover(isPresented: $showingTrueFalse) {
            TrueFalseRaceView { showingTrueFalse = false }
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            QuickQuizView { showingQuiz = false }
        }
        .fullScreenCover(isPresented: $showingMatch) {
            MatchPairsView { showingMatch = false }
        }
        .fullScreenCover(isPresented: $showingMemory) {
            MemoryMatchView { showingMemory = false }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("מִשְׂחָקִים 🎮")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text("בְּחַר מִשְׂחָק וְקָדִימָה!")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func gameCard(emoji: String, title: String, subtitle: String,
                          colors: [Color], action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            HStack(spacing: 16) {
                // Text first → in RTL it sits flush against the right edge; the
                // emoji medallion sits on the left. NOTE: in an RTL environment
                // `.leading` is the RIGHT edge (and `.trailing` is the left), so
                // right-aligning Hebrew here uses `.leading`.
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(emoji)
                    .font(.system(size: 56))
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(.white.opacity(0.22)))
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))
                    .float(amplitude: 5)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.45), lineWidth: 1.5))
            .glow(colors[0], radius: 16)
        }
        .buttonStyle(.juicy)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
    }
}
