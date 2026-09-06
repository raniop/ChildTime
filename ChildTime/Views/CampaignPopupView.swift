import SwiftUI

/// 📣 The in-app version of a campaign — shown once, on the next open, to the
/// people the push went to (and to those who turned pushes off). Parent: the
/// message + its action. Child: the child copy, never a price, and only
/// "בקש מאבא או אמא" when the campaign is about a pack.
struct CampaignPopupView: View {
    let campaign: Campaign
    let isChild: Bool
    /// The button: open the pack page / paywall / just dismiss.
    let onAct: () -> Void
    let onLater: () -> Void

    @State private var shown = false
    @State private var bob = false

    private var title: String { isChild ? (campaign.childTitle.isEmpty ? campaign.title : campaign.childTitle) : campaign.title }
    private var body_: String { isChild ? (campaign.childBody.isEmpty ? campaign.body : campaign.childBody) : campaign.body }
    private var pack: QuestionPack? { campaign.action.type == "pack" ? QuestionPacks.find(campaign.action.packID) : nil }
    private var cta: String {
        if isChild { return pack != nil ? "בַּקְּשׁוּ מֵאַבָּא אוֹ אִמָּא 💌" : "סַבָּבָּה! 👍" }
        switch campaign.action.type {
        case "pack":     return "שִׁלְחוּ לַיֶּלֶד שֶׁלִּי"
        case "tofyPlus": return "לְכָל הַפְּרָטִים"
        default:         return "הֵבַנְתִּי"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "14122A").opacity(shown ? 0.45 : 0).ignoresSafeArea()
                .onTapGesture { onLater() }
            VStack(spacing: 10) {
                Text(campaign.emoji.isEmpty ? (pack?.emoji ?? "🦁") : campaign.emoji)
                    .font(.system(size: 60))
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill((pack?.heroGradient ?? LinearGradient(colors: [Color(hex: "8CFFC4"), Color(hex: "7CF3FF")], startPoint: .topLeading, endPoint: .bottomTrailing)).opacity(0.45)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .offset(y: bob ? -3 : 3)
                    // Scoped to the hero — a global repeatForever transaction
                    // leaked into the sheet's entrance and left the button
                    // label floating above its background.
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: bob)
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body_)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let pack, !isChild {
                    HStack(spacing: 6) {
                        chip("מֻמְלָץ \(pack.gradesLabel)")
                        chip("\(pack.questionCount) שְׁאֵלוֹת")
                        chip("תּוֹסֶפֶת · לֹא כָּלוּל בְּטוֹפִי+")
                    }
                }
                Button { Haptic.light(); onAct() } label: {
                    Text(cta)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                Button { Haptic.light(); onLater() } label: {
                    Text("אוּלַי אַחַר כָּךְ")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(GlassInk.primary)
            .padding(16)
            .background(
                LinearGradient(colors: [Color(hex: "8A63FF"), Color(hex: "5E60CE")], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.32), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(14)
            .frame(maxWidth: 480)
            .offset(y: shown ? 0 : 500)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { bob = true }
        }
    }

    private func chip(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.12)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .lineLimit(1).minimumScaleFactor(0.8)
    }
}
