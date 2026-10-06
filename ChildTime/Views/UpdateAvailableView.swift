import SwiftUI

/// 🔄 The three faces of "there is a newer Tofy".
///
/// Shape and weights follow `CampaignPopupView` on purpose — a family has already
/// learned what a sheet rising from the bottom of this app means, and an update
/// notice is not the place to teach them a second language.
///
/// The parent sheet is the only one that can leave the app. A child cannot finish
/// an App Store update anyway (it wants an Apple ID password), and sending a kid
/// out of a Kids Category app is exactly what 1.3 forbids — the rejection this
/// project already lived through once. So the child's notice has one button and
/// it closes the sheet.

// MARK: - The lion, at whatever size the moment deserves

private struct UpdateHero: View {
    var size: CGFloat = 112
    @State private var bob = false

    var body: some View {
        Group {
            if let img = Character2DImages.image("lion") {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Text("🦁").font(.system(size: size * 0.62))   // art missing — never an empty box
            }
        }
        // The image OWNS the layout size; the halo is drawn behind it and takes
        // no space at all, so it can never push the title or the notes around.
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "7CF3FF").opacity(0.50),
                                              Color(hex: "8CFFC4").opacity(0.18),
                                              .clear],
                                     center: .center, startRadius: 2, endRadius: size * 0.60))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 12)
        )
        .shadow(color: Color(hex: "1B1340").opacity(0.26), radius: 12, y: 7)
        .offset(y: bob ? -3 : 3)
        .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: bob)
        .onAppear { bob = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Parent: what changed, and a way to get it

struct UpdateAvailableSheet: View {
    /// "🏅 פרס…" → ("🏅", "פרס…"); a line that doesn't open with an emoji stays whole.
    static func splitEmoji(_ line: String) -> (String, String) {
        guard let first = line.first,
              first.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000) }),
              let space = line.firstIndex(of: " ") else { return ("", line) }
        return (String(line[..<space]), String(line[line.index(after: space)...]))
    }

    let onUpdate: () -> Void
    let onLater: () -> Void

    @ObservedObject private var config = AppUpdateConfig.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    UpdateHero().padding(.top, 14)

                    VStack(spacing: 5) {
                        Text(tr("יֵשׁ גִּרְסָה חֲדָשָׁה שֶׁל טוֹפִי"))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        if !config.versionName.isEmpty {
                            Text(tr("\(config.versionName) מְחַכָּה לָכֶם בְּ-App Store"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    if !config.displayNotes.isEmpty {
                        VStack(spacing: 9) {
                            ForEach(Array(config.displayNotes.enumerated()), id: \.offset) { _, line in
                                // The emoji sits in a fixed column, so every line's
                                // text starts at the same edge (🏅 / ⏱ / 🛠 differ in width).
                                let (icon, text) = Self.splitEmoji(line)
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    if !icon.isEmpty {
                                        Text(icon).font(.system(size: 17)).frame(width: 24)
                                    }
                                    Text(text)
                                        .font(.system(size: 14.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 13).padding(.horizontal, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.white.opacity(0.10))
                                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(.white.opacity(0.16), lineWidth: 1))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                Button {
                    Haptic.light()
                    onUpdate()
                } label: {
                    Text(tr("עַדְכְּנוּ עַכְשָׁיו"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2B1C04"))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(colors: [Color(hex: "FFD66B"), Color(hex: "FFB32E")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                }
                .buttonStyle(.plain)

                Button(tr("אַחַר כָּךְ")) { onLater() }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.top, 12).padding(.bottom, 6)

                Text(tr("מֻתְקָן אֶצְלְכֶם: \(AppInfo.version) (\(AppInfo.build))"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The approved mockup's ground: a deep indigo panel. The app's bright
        // backdrop washed the glass rows out until they read as empty bands.
        .background(
            LinearGradient(colors: [Color(hex: "4B3AA8"), Color(hex: "3B3277")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .environment(\.layoutDirection, .app)
    }
}

// MARK: - Child: tell them, and send them to a grown-up — not to the App Store

struct UpdateKidNotice: View {
    let onOK: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            UpdateHero()
            Text(tr("יֵשׁ טוֹפִי חָדָשׁ! ✨"))
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text(tr("בִּקְשׁוּ מֵאַבָּא אוֹ מֵאִמָּא לְעַדְכֵּן,\nוְיִהְיוּ דְּבָרִים חֲדָשִׁים לְשַׂחֵק בָּהֶם 💛"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // One button, and it closes the sheet. No path out of the app.
            Button {
                Haptic.light()
                onOK()
            } label: {
                Text(tr("סַבָּבָּה! 👍"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2B1C04"))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "FFD66B"), Color(hex: "FFB32E")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            LinearGradient(colors: [Color(hex: "4B3AA8"), Color(hex: "3B3277")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .environment(\.layoutDirection, .app)
    }
}

// MARK: - Below minBuild: this copy can no longer be trusted against the server

struct ForcedUpdateView: View {
    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                UpdateHero(size: 136)
                Text(tr("צָרִיךְ לְעַדְכֵּן כְּדֵי לְהַמְשִׁיךְ"))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                Text(tr("הַגִּרְסָה שֶׁמֻּתְקֶנֶת כָּאן כְּבָר לֹא מְדַבֶּרֶת עִם הַשֵּׁרֵת שֶׁל טוֹפִי. הָעִדְכּוּן לוֹקֵחַ רֶגַע — וְכָל הַזְּמַן, הַכּוֹכָבִים וְהַיַּהֲלוֹמִים נִשְׁמָרִים בַּמָּקוֹם."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10).padding(.horizontal, 8)
                Spacer()
                Link(destination: AppUpdateConfig.storeURL) {
                    Text(tr("עַדְכְּנוּ עַכְשָׁיו"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.juicy)
                .ctaGlass(Color(hex: "FFD66B"), Color(hex: "FFB32E"))
                Text(AppInfo.versionLine)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(GlassInk.secondary.opacity(0.7))
                    .padding(.top, 11).padding(.bottom, 10)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 480)
        }
        .environment(\.layoutDirection, .app)
        // No dismiss, no swipe-down, no X: the whole point is that this build
        // must not keep writing to the server.
        .interactiveDismissDisabled(true)
    }
}

#if DEBUG
/// DEMO_SCREEN only: presents a sheet over the app's own background, so the
/// screen is reviewed in the shape it will really have — not stretched to fill.
struct UpdateDemoHost<Content: View>: View {
    var detent: PresentationDetent = .large
    @ViewBuilder var content: () -> Content
    @State private var up = false
    var body: some View {
        ZStack { GlassBackdrop().ignoresSafeArea() }
            .sheet(isPresented: $up) { content().presentationDetents([detent]) }
            .onAppear { up = true }
    }
}
#endif
