import SwiftUI

struct WorldDetailView: View {
    let world: World
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    @State private var companion = CompanionController()
    @State private var startSession = false

    var currentRoom: Int { progress.progress(in: world.id) }
    var rewardPerCorrect: Int { settings.minutesPerCorrectAnswer }

    var body: some View {
        ZStack {
            world.gradient.gradient.ignoresSafeArea()
            SparkleField(count: 15, size: 14)

            VStack(spacing: AppSpacing.xl) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    StarCounter(value: progress.stars)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)

                Spacer()

                // World hero
                VStack(spacing: AppSpacing.md) {
                    Text(world.emoji)
                        .font(.system(size: 120))
                        .float()
                        .glow(world.glowColor, radius: 24)

                    Text(world.name)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("חדר \(currentRoom + 1) מתוך \(world.rooms)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                // Companion + bubble
                ZStack(alignment: .top) {
                    if let bubble = companion.bubbleText {
                        BubbleSpeech(text: bubble)
                            .offset(y: -10)
                    }
                    CompanionView(controller: companion, size: 100)
                        .offset(y: 70)
                }
                .frame(height: 180)

                // Quest summary
                VStack(spacing: AppSpacing.sm) {
                    Text("\(settings.questionsPerSession) שאלות → 🎁 קופסה")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("כל תשובה נכונה = \(rewardPerCorrect) דקות משחק")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.large))

                // Start button
                JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {
                    companion.cheer("יאללה!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        startSession = true
                    }
                } label: {
                    Label("יאללה!", systemImage: "play.fill")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: AppSpacing.xl)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                companion.cheer("מוכן לחדר \(currentRoom + 1)?")
            }
        }
        .fullScreenCover(isPresented: $startSession) {
            QuestionRunnerView(world: world)
                .onDisappear { dismiss() }
        }
    }
}

#Preview {
    WorldDetailView(world: Worlds.all[0])
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
