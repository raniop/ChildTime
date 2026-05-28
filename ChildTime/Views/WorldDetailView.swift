import SwiftUI

struct WorldDetailView: View {
    let world: World
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    @State private var companion = CompanionController()
    @State private var startSession = false
    @State private var heroAppeared = false

    private var isCompact: Bool { hsc == .compact }
    private var heroEmojiSize: CGFloat { isCompact ? 110 : 160 }
    private var worldNameSize: CGFloat { isCompact ? 38 : 52 }
    private var companionSize: CGFloat { isCompact ? 88 : 110 }
    private var ctaSize: CGFloat { isCompact ? 30 : 38 }

    var currentRoom: Int { progress.progress(in: world.id) }
    var rewardPerCorrect: Int { settings.minutesPerCorrectAnswer }

    var body: some View {
        ZStack {
            // Themed layered background
            world.gradient.gradient.ignoresSafeArea()
            themedOrbs
            WorldDecorations(world: world)
                .opacity(0.55)
            SparkleField(count: 22, size: 14)

            VStack(spacing: AppSpacing.lg) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.juicy)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppColor.starGold)
                            .font(.system(size: 18))
                        Text("\(progress.stars)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(AppColor.starGold.opacity(0.5), lineWidth: 1.5))
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)

                Spacer()

                // World hero — bigger, more dramatic
                VStack(spacing: AppSpacing.md) {
                    Text(world.emoji)
                        .font(.system(size: heroEmojiSize))
                        .float(amplitude: 8)
                        .shadow(color: world.glowColor.opacity(0.9), radius: 40)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
                        .scaleEffect(heroAppeared ? 1.0 : 0.3)
                        .rotationEffect(.degrees(heroAppeared ? 0 : -20))

                    Text(world.name)
                        .font(.system(size: worldNameSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                        .scaleEffect(heroAppeared ? 1 : 0.7)
                        .opacity(heroAppeared ? 1 : 0)

                    HStack(spacing: 8) {
                        Image(systemName: "door.left.hand.open")
                        Text("חדר \(currentRoom + 1) מתוך \(world.rooms)")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
                    .opacity(heroAppeared ? 1 : 0)
                }

                Spacer()

                // Companion + bubble
                ZStack(alignment: .top) {
                    if let bubble = companion.bubbleText {
                        BubbleSpeech(text: bubble)
                            .offset(y: -10)
                    }
                    CompanionView(controller: companion, size: companionSize)
                        .offset(y: 80)
                }
                .frame(height: 190)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)

                // Quest summary card
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.white)
                        Text("\(settings.questionsPerSession) שאלות → 🎁 קופסה")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("כל תשובה נכונה = \(rewardPerCorrect) דקות משחק")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: AppRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                )
                .padding(.horizontal, AppSpacing.lg)

                // Start button
                JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                    companion.cheer("יאללה!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        startSession = true
                    }
                } label: {
                    Label("יאללה! 🚀", systemImage: "play.fill")
                        .font(.system(size: ctaSize, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: AppSpacing.lg)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                heroAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                companion.cheer("מוכן לחדר \(currentRoom + 1)?")
            }
        }
        .fullScreenCover(isPresented: $startSession) {
            QuestionRunnerView(world: world)
                .onDisappear { dismiss() }
        }
    }

    @ViewBuilder
    private var themedOrbs: some View {
        switch world.id {
        case "numbers_kingdom": FloatingOrbs.castle()
        case "letter_tower":    FloatingOrbs.tower()
        case "dino_valley":     FloatingOrbs.valley()
        default:                FloatingOrbs.home()
        }
    }
}

#Preview {
    WorldDetailView(world: Worlds.all[0])
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
