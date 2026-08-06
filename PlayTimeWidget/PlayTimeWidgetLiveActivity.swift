import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// Live Activity UI for the child's remaining play time. The countdown uses
/// SwiftUI's `Text(timerInterval:)`, which ticks down on its own — no updates
/// from the app needed. (`PlayTimeActivityAttributes` is the shared type, a
/// member of both the app and this widget target.)
struct PlayTimeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlayTimeActivityAttributes.self) { context in
            // Lock screen / banner.
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.yellow.opacity(0.22)).frame(width: 50, height: 50)
                        Text("🎮").font(.system(size: 26))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("זְמַן מִשְׂחָק")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("נִשְׁאָר לְשַׂחֵק")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 8)
                    countdown(to: context.state.endsAt, size: 32).frame(minWidth: 96)
                }
                stopButton()
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("זמן משחק", systemImage: "gamecontroller.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.endsAt, size: 20).frame(minWidth: 72)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text("נִשְׁאָר זְמַן לְשַׂחֵק 🎮")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        stopButton()
                    }
                }
            } compactLeading: {
                Image(systemName: "gamecontroller.fill").foregroundStyle(.yellow)
            } compactTrailing: {
                countdown(to: context.state.endsAt, size: 15).frame(minWidth: 46)
            } minimal: {
                Image(systemName: "gamecontroller.fill").foregroundStyle(.yellow)
            }
            .keylineTint(.yellow)
        }
    }

    /// "עֲצֹר וּשְׁמֹר" — freezes a manual grant / banks earned time, then re-locks.
    /// Interactive Live Activity buttons need iOS 17+; on iOS 16 nothing shows.
    @ViewBuilder
    private func stopButton() -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: StopAndSavePlayIntent()) {
                Label("עֲצֹר וּשְׁמֹר ❄️", systemImage: "pause.fill")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.20), in: Capsule())
            }
            .buttonStyle(.plain)
            .tint(.white)
        }
    }

    private func countdown(to endsAt: Date, size: CGFloat) -> some View {
        Text(timerInterval: Date()...max(endsAt, Date().addingTimeInterval(1)), countsDown: true)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.yellow)
    }
}
