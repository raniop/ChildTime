import SwiftUI

/// Shown on a CHILD's device that hasn't joined yet: scan (or type) the code the
/// parent created for this child. On success the device joins the family and
/// lands straight on that child, ready to play.
struct ChildJoinView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var settings: ParentSettings
    @StateObject private var companion = CompanionController()
    @State private var code = ""
    @State private var showScanner = false
    @State private var showRemovalGate = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 22, size: 14)

            // Back to device-role choice — ONLY during first-time setup (in case
            // "child" was tapped by mistake). HIDDEN once this is an established
            // child device that was disconnected: it must never expose a one-tap
            // path to becoming a parent device. (A parent repurposes a device from
            // the parent-gated Settings instead.)
            if !settings.justDisconnected {
                VStack {
                    HStack {
                        Button {
                            Haptic.light()
                            settings.deviceRole = .unset
                        } label: {
                            Label("חֲזָרָה", systemImage: "chevron.backward")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .zIndex(2)
            }

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    CompanionView(controller: companion, size: 120)
                    if settings.justDisconnected {
                        Text("הַמַּכְשִׁיר נוּתַּק")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Label("סִרְקוּ שׁוּב אֶת קוֹד הַהוֹרֶה כְּדֵי לְהַמְשִׁיךְ", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(AppColor.almostWarm.opacity(0.9), in: Capsule())
                        Text("הַהִתְקַדְּמוּת שֶׁלְּךָ שְׁמוּרָה בֶּעָנָן — שׁוּם דָּבָר לֹא אָבַד.")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("הֵיי! בּוֹאוּ נִתְחַבֵּר")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("בְּמַכְשִׁיר הַהוֹרֶה מוֹפִיעַ קוֹד QR לַיֶּלֶד.\nסִרְקוּ אוֹתוֹ כָּאן וְהַמַּכְשִׁיר יִתְחַבֵּר.")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    Button { showScanner = true } label: {
                        Label("סִרְקוּ קוֹד QR", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .glow(AppColor.starGold, radius: 12)
                    }
                    .buttonStyle(.juicy)

                    VStack(spacing: 8) {
                        TextField("אוֹ הַקְלִידוּ אֶת הַקּוֹד", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        Button { JoinCoordinator.shared.present(code) } label: {
                            Text("הִתְחַבְּרוּ")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .disabled(working || code.count < 6)
                        .opacity(code.count < 6 ? 0.5 : 1)
                    }

                    if let message {
                        Text(message)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    // Escape hatch: a child device blocks app deletion, so a device
                    // stranded HERE (can't reach the in-app parent controls) would be
                    // impossible to uninstall. This lets a parent — with the code —
                    // open a 5-minute deletion window from the disconnected screen.
                    Button { showRemovalGate = true } label: {
                        Label("אֲנִי הוֹרֶה · פְּתִיחַת מְחִיקַת הָאַפְּלִיקַצְיָה", systemImage: "trash")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScannerView { scanned in
                    showScanner = false
                    JoinCoordinator.shared.present(scanned)
                }
                .ignoresSafeArea()
                .navigationTitle("סריקת קוד")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("ביטול") { showScanner = false } } }
            }
        }
        .sheet(isPresented: $showRemovalGate) {
            // respectSession:false → always re-authenticate; a child must never open
            // the deletion window off a stale unlock.
            ParentGateView(allowClose: true,
                           gateTitle: "אֵזוֹר הוֹרִים",
                           gateReason: "כְּדֵי לְאַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת — הַזִּינוּ קוֹד הוֹרֶה",
                           useFaceID: true,
                           respectSession: false) {
                AppRemovalUnlockView { showRemovalGate = false }
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .environmentObject(settings)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .onAppear {
            // The confirmed child-join hands off here via pendingJoinPayload.
            if let payload = settings.pendingJoinPayload, !payload.isEmpty {
                settings.pendingJoinPayload = nil
                join(payload)
            }
        }
        // …and when the confirmation sets it while this screen is already showing.
        .onChangeCompat(of: settings.pendingJoinPayload) { _, payload in
            if let payload, !payload.isEmpty {
                settings.pendingJoinPayload = nil
                join(payload)
            }
        }
    }

    /// Payload is "CODE|childID". Redeem the code (join the family), then land on
    /// that specific child.
    private func join(_ raw: String) {
        // Accept a raw "CODE|childID" OR a scanned/opened join Universal Link.
        let payload = JoinLink.payload(from: raw)
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        guard let codePart = parts.first, codePart.count >= 6 else { return }
        let codeChildID = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        Task {
            working = true
            message = "מִתְחַבְּרִים…"
            // A child play-device only BINDS to one existing child — it must not
            // upload its local profiles as new kids (that spawned phantom children).
            let ok = await household.redeemInvite(code: codePart, bringLocalChildren: false)
            guard ok else {
                message = household.lastError ?? "קוֹד לֹא תָּקִין"
                working = false
                return
            }
            // Which child is THIS device for? In priority: the code-string's
            // childID (scanned QR), the invite doc's childID (typed per-child code),
            // or — as a last resort — the family's single child.
            let resolved: UUID? = codeChildID
                ?? household.redeemedInviteChildID.flatMap { UUID(uuidString: $0) }
                ?? {
                    let ids = household.household?.childIDs ?? []
                    if ids.count == 1, let only = UUID(uuidString: ids[0]) { return only }
                    return nil
                }()
            guard let cid = resolved else {
                // Joined, but a bare code can't disambiguate among several kids.
                message = "כִּמְעַט! בְּמַכְשִׁיר הַהוֹרֶה לַחֲצוּ עַל הַיֶּלֶד הַסְּפֵּצִיפִי כְּדֵי לְקַבֵּל קוֹד אִישִׁי, אוֹ סִרְקוּ אֶת קוֹד הַ-QR שֶׁלּוֹ."
                working = false
                return
            }
            // Bind THIS device to this specific child.
            TofyLink("JOIN: binding this device to child \(cid.uuidString.prefix(8))")
            ParentSettings.shared.joinedChildID = cid.uuidString
            ParentSettings.shared.justDisconnected = false   // reconnected → clear
            profiles.setActiveID(cid)
            await household.registerDevice(forChildID: cid)
            // PULL the child's existing cloud progress NOW (stars / diamonds /
            // play-minutes) so it shows immediately — otherwise the fresh device
            // stays blank until an app restart re-subscribes. apply() adopts the
            // cloud revision, so this never pushes a blank over the cloud.
            if let cloud = await RemoteSyncManager.shared.fetchSnapshot(for: cid) {
                TofyLink("JOIN: applying cloud snapshot stars=\(cloud.stars) diamonds=\(cloud.diamonds) min=\(cloud.pendingMinutes)")
                ProgressStore.shared.apply(cloud)
            } else {
                TofyLink("JOIN: NO cloud snapshot for \(cid.uuidString.prefix(8)) — profile will show empty until sync delivers one")
            }
            RemoteSyncManager.shared.start()   // ensure live sync now follows this child
            TimeTransferManager.shared.start()
            AppAnalytics.deviceJoined(kind: DeviceIdentity.kind)
            message = "הִתְחַבַּרְתֶּם! 🎉"
            working = false
        }
    }
}

/// Shown behind the parent gate from the disconnected screen: opens a 5-minute
/// window in which the (otherwise deletion-locked) child device can be uninstalled.
private struct AppRemovalUnlockView: View {
    var onDone: () -> Void
    @State private var opened = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            VStack(spacing: 20) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 64)).foregroundStyle(AppColor.flameOrange)
                    .glow(AppColor.flameOrange, radius: 12)
                Text("מְחִיקַת הָאַפְּלִיקַצְיָה")
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(opened
                     ? "נִפְתַּח חַלּוֹן שֶׁל 5 דַּקּוֹת.\nצְאוּ לְמָסַךְ הַבַּיִת ← לְחִיצָה אֲרוּכָּה עַל טוֹפִי ← \u{201C}הָסֵר אַפְּלִיקַצְיָה\u{201D}. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד."
                     : "בְּמַכְשִׁיר יֶלֶד הַמְּחִיקָה חֲסוּמָה. פִּתְחוּ חַלּוֹן קָצָר כְּדֵי לְהָסִיר אֶת טוֹפִי מִמָּסַךְ הַבַּיִת.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 24)
                if opened {
                    Button { onDone() } label: {
                        Text("סְגִירָה").font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.white.opacity(0.18), in: Capsule())
                    }.buttonStyle(.juicy).padding(.horizontal, 40)
                } else {
                    Button {
                        Haptic.medium()
                        ParentSettings.shared.appRemovalUnlockedUntil = Date().addingTimeInterval(5 * 60)
                        ShieldManager.shared.setAppRemovalLocked(false)
                        withAnimation { opened = true }
                    } label: {
                        Label("אַפְשְׁרוּ מְחִיקָה לְ-5 דַּקּוֹת", systemImage: "trash")
                            .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(AppColor.flameOrange.opacity(0.9), in: Capsule())
                    }.buttonStyle(.juicy).padding(.horizontal, 32)
                }
            }
            .padding(.top, 40)
        }
    }
}

#Preview {
    ChildJoinView()
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
