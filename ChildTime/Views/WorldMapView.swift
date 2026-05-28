import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager

    @State private var companion = CompanionController()
    @State private var selectedWorld: World?
    @State private var showDailyChest = false
    @State private var showingParentGate = false
    @State private var showingDemo = false
    @State private var lastSeenStars = 0

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            VStack(spacing: AppSpacing.lg) {
                topBar
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer().frame(height: AppSpacing.xs)
                        ForEach(Worlds.all) { world in
                            WorldCard(
                                world: world,
                                isUnlocked: progress.unlockedWorlds.contains(world.id),
                                currentRoom: progress.progress(in: world.id),
                                starsHeld: progress.stars
                            ) {
                                selectedWorld = world
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 200)
                }
                Spacer(minLength: 0)
            }

            // Bottom CTAs
            VStack {
                Spacer()
                bottomCTAs
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
            }

            // Companion floats around
            VStack {
                Spacer()
                HStack {
                    ZStack(alignment: .topLeading) {
                        CompanionView(controller: companion, size: 110)
                            .padding(.leading, AppSpacing.lg)
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble)
                                .offset(x: 100, y: -10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Spacer()
                }
            }
            .padding(.bottom, 140)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)
        }
        .onAppear {
            lastSeenStars = progress.stars
            greetIfNeeded()
            checkWorldUnlocks()
        }
        .onChange(of: progress.stars) { _, new in
            if new > lastSeenStars {
                companion.cheer()
            }
            lastSeenStars = new
            checkWorldUnlocks()
        }
        .fullScreenCover(item: $selectedWorld) { world in
            WorldDetailView(world: world)
        }
        .fullScreenCover(isPresented: $showDailyChest) {
            DailyChestView()
        }
        .sheet(isPresented: $showingParentGate) {
            ParentGateView()
        }
        .fullScreenCover(isPresented: $showingDemo) {
            ZStack(alignment: .topTrailing) {
                DemoView()
                Button { showingDemo = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Gear (parent gate)
            Button {
                showingParentGate = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .onLongPressGesture(minimumDuration: 1.5) { showingDemo = true }

            Spacer()

            MinuteCounter(minutes: progress.pendingMinutes)
            StarCounter(value: progress.stars)
            StarCounter(value: progress.gems, icon: "diamond.fill", color: AppColor.gemPurple)

            XPBar(
                level: progress.companionLevel,
                xp: progress.xp,
                xpForCurrentLevel: progress.xpForCurrentLevel,
                xpForNextLevel: progress.xpForNextLevel
            )
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    @ViewBuilder
    private var bottomCTAs: some View {
        VStack(spacing: AppSpacing.md) {
            if progress.dailyChestAvailable {
                Button {
                    showDailyChest = true
                } label: {
                    HStack {
                        Text("🎁")
                            .font(.system(size: 30))
                        Text("קופסה יומית מחכה!")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.left")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppGradient.portal)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .glow(AppColor.gemPurple, radius: 12)
                }
                .buttonStyle(.juicy)
            }

            if progress.pendingMinutes > 0 {
                JuicyButton(
                    gradient: AppGradient.castle,
                    glowColor: AppColor.flameOrange
                ) {
                    redeemMinutes()
                } label: {
                    Label("פתחו לי \(progress.pendingMinutes) דקות לשחק", systemImage: "gamecontroller.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
            }
        }
    }

    // MARK: - Actions

    private func greetIfNeeded() {
        // Greet once per session
        if progress.dayStreak == 0 {
            companion.cheer("היי! יאללה הרפתקה 🌟")
        } else {
            companion.cheer("חזרת!")
        }
    }

    private func checkWorldUnlocks() {
        for world in Worlds.all where !progress.unlockedWorlds.contains(world.id) {
            if progress.canUnlock(world: world) {
                progress.unlockWorld(world.id)
                companion.wow("\(world.emoji) \(world.name) נפתח!")
            }
        }
    }

    private func redeemMinutes() {
        let minutes = progress.consumePendingMinutes()
        guard minutes > 0 else { return }
        shields.unlock(minutes: minutes)
        progress.startUnlock(minutes: minutes)
    }
}

#Preview {
    WorldMapView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
