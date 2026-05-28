import SwiftUI

struct StarCounter: View {
    let value: Int
    var icon: String = "star.fill"
    var color: Color = AppColor.starGold

    @State private var displayed: Int = 0
    @State private var pop: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .scaleEffect(pop ? 1.4 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: pop)
            Text("\(displayed)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .contentTransition(.numericText(value: Double(displayed)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .glow(color, radius: 10)
        .onAppear { displayed = value }
        .onChange(of: value) { _, new in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                displayed = new
            }
            pop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { pop = false }
        }
    }
}

struct MinuteCounter: View {
    let minutes: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .foregroundStyle(AppColor.successMint)
            Text("\(minutes) דק׳")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .contentTransition(.numericText(value: Double(minutes)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .glow(AppColor.successMint, radius: minutes > 0 ? 12 : 0)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 20) {
            StarCounter(value: 47)
            StarCounter(value: 12, icon: "diamond.fill", color: AppColor.gemPurple)
            MinuteCounter(minutes: 8)
        }
    }
}
