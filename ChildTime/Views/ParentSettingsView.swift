import SwiftUI
import FamilyControls

struct ParentSettingsView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var subs: SubscriptionManager
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showAllowedPicker = false
    @State private var allowedSelection = FamilyActivitySelection()
    @State private var showChangePIN = false
    @State private var showWhatsNew = false
    @State private var showSignIn = false
    @State private var showPaywall = false
    @State private var showDashboard = false
    @State private var showFamilyLinking = false
    @State private var exportURL: URL?
    @State private var showDeleteAllConfirm = false
    @State private var showResetDeviceConfirm = false
    @State private var showRolePickerConfirm = false
    @State private var showSignOutConfirm = false
    @State private var deleting = false
    @State private var testPushMessage: String?
    @State private var removalNote: String?
    @State private var requestingShield = false

    var body: some View {
        NavigationStack {
            // Five doors, each with a one-line summary (Rani: the old single
            // form was "a pile nobody would open"). Tofy+ lives on the home.
            ScrollView {
                VStack(spacing: 12) {
                    // 🌍 Written in both languages, so a parent who switched by
                    // mistake can always find the way back.
                    if LanguageStore.shared.available.count > 1 {
                        NavigationLink { LanguagePickerView() } label: {
                            HStack(spacing: 12) {
                                Text("🌍").font(.system(size: 22))
                                    .frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.22)))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.32), lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr("שָׁפָה · Language")).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(GlassInk.primary)
                                    Text(LanguageStore.shared.current.nativeName).font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 14, weight: .bold)).foregroundStyle(GlassInk.tertiary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .glassPane(radius: 22, strength: 0.14)
                        }
                        .buttonStyle(.plain)
                    }
                    menuRow("👪", tr("הַמִּשְׁפָּחָה"), familySummary) {
                        subScreen(tr("הַמִּשְׁפָּחָה")) { familySection; syncSection }
                    }
                    menuRow("🎮", tr("זְמַן מָסָךְ וּפְרָסִים"), rewardsSummary) {
                        subScreen(tr("זְמַן מָסָךְ וּפְרָסִים")) { rewardSection; penaltySection; smartFeedSection }
                    }
                    menuRow("🔔", tr("הַתְרָאוֹת"), notificationsSummary) {
                        subScreen(tr("הַתְרָאוֹת")) { notificationsSection; insightNotificationsSection }
                    }
                    menuRow("🔐", tr("קוֹד הוֹרֶה"), pinSummary) {
                        subScreen(tr("קוֹד הוֹרֶה")) { pinSection }
                    }
                    menuRow("📱", tr("אַפְּלִיקַצְיוֹת וּנְעִילָה"), devicesSummary, soft: true) {
                        subScreen(tr("אַפְּלִיקַצְיוֹת וּנְעִילָה")) {
                            if settings.deviceRole != .parent || shields.isAuthorized { authorizationSection }
                            appsSection; soundsSection; deviceSection
                        }
                    }
                    menuRow("ℹ️", tr("אוֹדוֹת וּפְרָטִיּוּת"), tr("\(AppInfo.versionLine) · יִצּוּא, מְחִיקָה"), soft: true) {
                        subScreen(tr("אוֹדוֹת וּפְרָטִיּוּת")) { versionSection; privacySection }
                    }
                }
                .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(GlassBackdrop())
            .environment(\.colorScheme, .dark)
            .navigationTitle(tr("הַגְדָּרוֹת"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("סיום")) { dismiss() }
                }
            }
            .tofyActivityPicker(title: PickerCopy.blocked.title, header: PickerCopy.blocked.header, footer: PickerCopy.blocked.footer, isPresented: $showAppPicker, selection: $pickerSelection)
            .onChangeCompat(of: pickerSelection) { _, new in
                settings.activitySelectionData = SelectionStorage.encode(new)
                shields.applyDefaultLock()
            }
            .tofyActivityPicker(title: PickerCopy.allowList.title, header: PickerCopy.allowList.header, footer: PickerCopy.allowList.footer, isPresented: $showAllowedPicker, selection: $allowedSelection)
            .onChangeCompat(of: allowedSelection) { _, new in
                settings.allowedAppsData = SelectionStorage.encode(new)
                shields.applyDefaultLock()
            }
            .onAppear {
                pickerSelection = SelectionStorage.decode(settings.activitySelectionData)
                allowedSelection = SelectionStorage.decode(settings.allowedAppsData)
            }
            .sheet(isPresented: $showChangePIN) {
                ChangePINView()
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
                    .environmentObject(auth)
                    .environment(\.layoutDirection, .app)
            }
            .sheet(isPresented: $showFamilyLinking) {
                AddParentView()
                    .environment(\.layoutDirection, .app)
            }
        }
    }

    /// "משפחת גולן" — one name for the whole household (Rani: the dashboard
    /// listed each parent by name; a family deserves a name of its own).
    @State private var familyNameDraft: String = HouseholdManager.shared.familyNameShown ?? ""
    private var familySection: some View {
        Section {
            HStack {
                Text("👪")
                TextField("", text: $familyNameDraft,
                          prompt: Text(tr("לְמָשָׁל: מִשְׁפַּחַת גּוֹלָן")).foregroundColor(.white.opacity(0.6)))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .submitLabel(.done)
                    .onSubmit { household.setFamilyName(familyNameDraft) }
                if familyNameDraft != (household.familyNameShown ?? "") {
                    Button(tr("שִׁמְרוּ")) { household.setFamilyName(familyNameDraft) }
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.92)))
                        .buttonStyle(.plain)
                }
            }
        } header: {
            Text(tr("שֵׁם הַמִּשְׁפָּחָה"))
        } footer: {
            Text(tr("מוֹפִיעַ בְּמָסָךְ הַהוֹרִים וּבְהוֹדָעוֹת — לְכָל הַהוֹרִים בַּמִּשְׁפָּחָה."))
        }
        .glassRows()
    }

    // MARK: - Menu

    private func menuRow<D: View>(_ emoji: String, _ title: String, _ summary: String, soft: Bool = false,
                                  @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.22)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.32), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(GlassInk.primary)
                    Text(summary).font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(GlassInk.secondary)
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: AppSymbol.forwardChevron).font(.system(size: 14, weight: .bold)).foregroundStyle(GlassInk.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassPane(radius: 22, strength: soft ? 0.09 : 0.14)
        }
        .buttonStyle(.plain)
    }

    private func subScreen<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        Form { content() }
            .glassForm()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var familySummary: String {
        let parents = household.linkedParentSummaries.isEmpty
            ? (auth.displayName ?? tr("הוֹרֶה")) : household.linkedParentSummaries.joined(separator: ", ")
        let kids = profiles.profiles.count
        return tr("\(parents) · \(kids == 1 ? tr("יֶלֶד אֶחָד") : tr("\(kids) יְלָדִים"))")
    }
    private var rewardsSummary: String {
        var t = tr("\(settings.batchAnswers) תְּשׁוּבוֹת = \(settings.batchMinutes) דַּקּוֹת")
        if settings.dailyCapEnabled { t += tr(" · מַקְסִימוּם \(settings.maxMinutesPerDay) דַּק׳ בְּיוֹם") }
        return t
    }
    private var notificationsSummary: String {
        let push = PushManager.shared.authorized ? tr("פּוֹעֲלוֹת") : tr("כְּבוּיוֹת")
        return tr("\(push) · תּוֹבָנוֹת \(freqShortLabel(settings.parentInsightFrequency)) בְּיוֹם")
    }
    private var pinSummary: String { settings.faceIDForParentGate ? tr("Face ID פָּעִיל · שִׁנּוּי קוֹד") : tr("קוֹד בִּלְבַד · שִׁנּוּי קוֹד") }
    private var devicesSummary: String {
        settings.deviceRole == .parent ? tr("מֻגְדָּר בַּמַּכְשִׁיר שֶׁל כָּל יֶלֶד") : tr("אֵילוּ אַפְּלִיקַצְיוֹת נְעוּלוֹת בַּמַּכְשִׁיר הַזֶּה")
    }

    private var dashboardSection: some View {
        Section {
            Button {
                showDashboard = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3)
                        .foregroundStyle(AppColor.successMint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("מבט-על על המשפחה"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text(tr("\(profiles.profiles.count) פרופילים • זמן, ניקוד, ואיפוסים"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: AppSymbol.forwardChevron)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .glassRows()
    }

    private var premiumSection: some View {
        Section {
            if subs.isPremium {
                // Active subscriber
                HStack(spacing: 12) {
                    Text("👑").font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("טופי+ פעיל"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                        Text(premiumStatusSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(tr("נהל מנוי ב-Apple ID"), systemImage: "gear")
                }
            } else {
                // Upsell card
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Text("👑").font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("שדרג ל-טופי+"))
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text(tr("כל הנושאים, כל העולמות, פרופילים לכל ילד"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: AppSymbol.forwardChevron)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await subs.restorePurchases() }
                } label: {
                    Label(tr("שחזר רכישה קיימת"), systemImage: "arrow.clockwise")
                        .font(.caption)
                }
            }
        } header: {
            Text(tr("מנוי"))
        } footer: {
            if !subs.isPremium {
                Text(tr("ניסיון 7 ימים חינם במסלול השנתי. ניתן לבטל בכל עת בהגדרות Apple ID."))
                    .font(.caption2)
            } else {
                EmptyView()
            }
        }
        .glassRows()
    }

    private var premiumStatusSubtitle: String {
        switch subs.subscriptionState {
        case .active(let expires?, let willRenew):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.locale = LanguageStore.shared.current.locale
            return willRenew
                ? tr("מתחדש ב-\(df.string(from: expires))")
                : tr("פעיל עד \(df.string(from: expires))")
        case .active(nil, _):
            return tr("רכישה לכל החיים ✨")
        case .inTrial(let expires):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.locale = LanguageStore.shared.current.locale
            return tr("ניסיון חינם עד \(df.string(from: expires))")
        default:
            return ""
        }
    }

    private var authorizationSection: some View {
        Group {
        insightNotificationsSection
        Section(tr("הרשאות")) {
            HStack {
                Image(systemName: shields.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(shields.isAuthorized ? .green : .orange)
                VStack(alignment: .leading) {
                    Text(shields.isAuthorized ? tr("Family Controls מאושר") : tr("צריך אישור"))
                        .font(.headline)
                    if let err = shields.authorizationError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    } else if !shields.isAuthorized {
                        Text(tr("בלי זה לא נוכל לחסום אפליקציות"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !shields.isAuthorized {
                    // Visible feedback: a spinner while Apple's prompt is up, and
                    // a fresh error line if it fails again (so the tap never looks
                    // like it "did nothing").
                    Button {
                        Task {
                            requestingShield = true
                            await shields.requestAuthorizationIfNeeded()
                            requestingShield = false
                        }
                    } label: {
                        if requestingShield {
                            ProgressView().tint(.white)
                        } else {
                            Text(shields.authorizationError == nil ? tr("בקש") : tr("נסו שוב"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(requestingShield)
                }
            }
        }
        .glassRows()
        }
        .glassRows()
    }

    /// Moved here from the parent home (the home is now the approved glass
    /// design: greeting, child cards, version — nothing else).
    private var insightNotificationsSection: some View {
        Section {
            Picker(tr("תְּדִירוּת"), selection: $settings.parentInsightFrequency) {
                ForEach(ParentSettings.InsightFrequency.allCases) { f in
                    Text(freqShortLabel(f)).tag(f)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(tr("התראות תובנות להורה"))
        } footer: {
            Text(tr("עדכונים קצרים ואישיים על כל ילד — במה השתפר, איפה התקשה ומה לתרגל."))
        }
        .glassRows()
    }

    private func freqShortLabel(_ f: ParentSettings.InsightFrequency) -> String {
        switch f {
        case .off:    return tr("כבוי")
        case .once:   return tr("פעם")
        case .twice:  return tr("פעמיים")
        case .thrice: return tr("3 פעמים")
        }
    }

    private var syncSection: some View {
        Section(tr("סנכרון בין מכשירים")) {
            if auth.isSignedIn {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.displayName ?? auth.email ?? tr("מחובר"))
                            .font(.headline)
                        if let email = auth.email, email != auth.displayName {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let p = auth.provider {
                            Text(p == .apple ? tr("דרך Apple") : tr("דרך Google"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                // Co-parents in the family (names come from the household doc, so no
                // cross-account reads). Excludes anonymous child play-devices + self.
                ForEach(household.linkedParentSummaries, id: \.self) { name in
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(AppColor.gemPurple).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.headline)
                            Text(tr("הוֹרֶה בַּמִּשְׁפָּחָה")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Button {
                    showFamilyLinking = true
                } label: {
                    Label(tr("הוֹסִיפוּ הוֹרֶה לַמִּשְׁפָּחָה"), systemImage: "person.2.badge.plus.fill")
                }
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label(tr("התנתק ומחק מהמכשיר"), systemImage: "rectangle.portrait.and.arrow.right")
                }
                .alert(tr("להתנתק ולמחוק הכול מהמכשיר?"), isPresented: $showSignOutConfirm) {
                    Button(tr("התנתק ומחק"), role: .destructive) {
                        HouseholdManager.shared.resetThisDevice()
                        dismiss()
                    }
                    Button(tr("בטל"), role: .cancel) {}
                } message: {
                    Text(tr("המכשיר יחזור למצב התחלתי לגמרי — בלי חשבון, בלי קוד הורה, בלי נתונים מקומיים (כאילו הותקן מחדש). המשפחה וההתקדמות בענן נשמרות — התחברות מחדש תשחזר אותן."))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("התחבר כדי שההתקדמות של הילד תישמר גם ב-iPad וגם ב-iPhone."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showSignIn = true
                    } label: {
                        Label(tr("התחבר עם Apple או Google"), systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
            if let err = auth.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .glassRows()
    }

    @StateObject private var push = PushManager.shared

    private var notificationsSection: some View {
        Section {
            if push.authorized {
                Label(tr("התראות פעילות"), systemImage: "bell.badge.fill")
                    .foregroundStyle(AppColor.successMint)
            } else {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Label(tr("הפעל התראות חיות"), systemImage: "bell.fill")
                }
            }
            Button {
                Task { testPushMessage = await push.sendTestPush() }
            } label: {
                Label(tr("שלח התראת בדיקה"), systemImage: "paperplane.fill")
            }
            if let testPushMessage {
                Text(testPushMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(tr("התראות להורה"))
        } footer: {
            Text(tr("קבלו עדכון כשהילד מתחיל ומסיים לשחק, פותח רצף, זוכה בגלגל מזל או מגלה תחום חדש — וגם דוח שבועי. ההתראות נשלחות בין המכשירים בבית. \"שלח התראת בדיקה\" שולח התראה אליכם עכשיו כדי לוודא שהכול עובד."))
        }
        .glassRows()
        .task { await push.refreshAuthorizationStatus() }
        .glassRows()
    }

    private var rewardSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(AppColor.successMint)
                Text(tr("כל \(settings.batchAnswers) תשובות נכונות = \(settings.batchMinutes) דקות משחק"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
            }
            Stepper(
                tr("תשובות נכונות לתגמול: \(settings.batchAnswers)"),
                value: $settings.batchAnswers,
                in: 1...30
            )
            Stepper(
                tr("דקות משחק לתגמול: \(settings.batchMinutes)"),
                value: $settings.batchMinutes,
                in: 1...30
            )
            Stepper(
                tr("שאלות בכל סבב: \(settings.questionsPerSession)"),
                value: $settings.questionsPerSession,
                in: 15...30
            )
        } header: {
            Text(tr("תגמול"))
        } footer: {
            Text(tr("הילד מרוויח \(settings.batchMinutes) דקות משחק על כל \(settings.batchAnswers) תשובות נכונות. אפשר לשנות את שני המספרים. ברירת המחדל: 10 תשובות = 4 דקות."))
        }
        .glassRows()
    }

    private var smartFeedSection: some View {
        Section {
            Stepper(
                tr("גלגל מזל כל \(settings.questionsPerWheel) שאלות"),
                value: $settings.questionsPerWheel,
                in: 5...50,
                step: 5
            )
        } header: {
            Text(tr("פיד למידה חכם"))
        } footer: {
            Text(tr("ב\"טופי טיים\" המערכת בונה לכל ילד פיד אישי: 80% מהנושאים שהוא אוהב ו-20% תחומים חדשים לגילוי. הפיד משתפר אחרי כל שאלה. כל \(settings.questionsPerWheel) שאלות הילד מרוויח סיבוב חינם בגלגל המזל."))
        }
        .glassRows()
    }


    private var penaltySection: some View {
        let perMistake = progress.mistakePenaltyMinutes(minutesPerCorrect: settings.minutesPerCorrectAnswer)
        return Section {
            Toggle(tr("טעויות עולות זמן"), isOn: $settings.penaltyEnabled)
        } header: {
            Text(tr("טעויות ולולאת תיקון"))
        } footer: {
            Text(settings.penaltyEnabled
                ? tr("כל טעות מורידה \(perMistake) דק' (חצי מתגמול תשובה נכונה) — אבל הילד יכול להחזיר את הזמן מיד: תשובה נכונה ונקייה בשאלה הבאה מחזירה את כל הזמן שירד. אף פעם לא מוצג לילד \"טעית\" או \"הפסדת\".")
                : tr("כבוי. הילד לא יאבד זמן גם אם יטעה הרבה."))
        }
        .glassRows()
    }

    private var soundsSection: some View {
        Section {
            Toggle(tr("צלילים פעילים"), isOn: $settings.soundsEnabled)
        } header: {
            Text(tr("צלילים"))
        } footer: {
            Text(tr("הצלילים באפליקציה רכים ומשמשים כפידבק על תשובות נכונות / שגויות. ניתן לכבות אותם לגמרי."))
        }
        .glassRows()
    }

    private var appsSection: some View {
        Section {
            Toggle(isOn: $settings.blockAllExceptAllowed) {
                Label(tr("חסום הכל חוץ מהמותר"), systemImage: "lock.shield.fill")
            }

            if settings.blockAllExceptAllowed {
                // Block-all-except-allowlist model.
                Button {
                    showAllowedPicker = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text(tr("בחר אפליקציות מותרות"))
                        Spacer()
                        let count = allowedSelection.applicationTokens.count
                            + allowedSelection.categoryTokens.count
                        if count > 0 {
                            Text(tr("\(count) מותרות")).foregroundStyle(.secondary)
                        }
                        Image(systemName: AppSymbol.forwardChevron).foregroundStyle(.secondary)
                    }
                }
                if allowedSelection.applicationTokens.isEmpty
                    && allowedSelection.categoryTokens.isEmpty {
                    Text(tr("⚠️ חשוב: בחרו אילו אפליקציות יישארו פתוחות — והקפידו לכלול את ChildTime (וכן אפליקציות חיוניות כמו טלפון). עד שתבחרו — לא ייחסם כלום, כדי לא לנעול את המכשיר בטעות."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Button(role: .destructive) {
                        allowedSelection = FamilyActivitySelection()
                    } label: {
                        Label(tr("נקה רשימת מותרות"), systemImage: "trash")
                    }
                }
            } else {
                // Classic block-list model.
                Button {
                    showAppPicker = true
                } label: {
                    HStack {
                        Image(systemName: "app.badge.fill")
                        Text(tr("בחר אפליקציות"))
                        Spacer()
                        let count = pickerSelection.applicationTokens.count
                            + pickerSelection.categoryTokens.count
                        if count > 0 {
                            Text(tr("\(count) נבחרו")).foregroundStyle(.secondary)
                        }
                        Image(systemName: AppSymbol.forwardChevron).foregroundStyle(.secondary)
                    }
                }
                if pickerSelection.applicationTokens.isEmpty
                    && pickerSelection.categoryTokens.isEmpty {
                    Text(tr("עדיין לא בחרת אפליקציות לחסום. בלי בחירה - לא יקרה כלום כשהילד פותח את ה-iPad."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button(role: .destructive) {
                        pickerSelection = FamilyActivitySelection()
                    } label: {
                        Label(tr("נקה בחירה"), systemImage: "trash")
                    }
                }
            }
        } header: {
            Text(tr("חסימת אפליקציות"))
        } footer: {
            Text(settings.blockAllExceptAllowed
                 ? tr("כל האפליקציות ייחסמו עד שהילד מרוויח זמן — חוץ מהאפליקציות שתבחרו כ\"מותרות\". חובה לכלול את ChildTime ברשימה.")
                 : tr("רק האפליקציות שתבחרו ייחסמו. כל השאר נשארות פתוחות."))
        }
        .glassRows()
    }

    /// Device-level escape hatches a parent may need from any device: send this
    /// device back to the role picker (e.g. it ended up the wrong role), and open a
    /// short window to uninstall the app (which is blocked on a child device).
    private var deviceSection: some View {
        Section {
            Button {
                showRolePickerConfirm = true
            } label: {
                Label(tr("הַחְלֵף תַּפְקִיד מַכְשִׁיר (חֲזָרָה לִבְחִירָה)"), systemImage: "person.2.badge.gearshape")
            }
            Button {
                Haptic.medium()
                settings.appRemovalUnlockedUntil = Date().addingTimeInterval(5 * 60)
                // Disarm any armed background monitor — its re-lock used to
                // instantly re-block the deletion this button just allowed.
                shields.cancelScheduledReshield()
                shields.setAppRemovalLocked(false)
                removalNote = tr("נִפְתַּח חַלּוֹן שֶׁל 5 דַּקּוֹת. צְאוּ לְמָסַךְ הַבַּיִת ← לְחִיצָה אֲרוּכָּה עַל טוֹפִי ← \u{201C}הָסֵר אַפְּלִיקַצְיָה\u{201D}. אַחַר כָּךְ הַנְּעִילָה חוֹזֶרֶת לְבַד.")
            } label: {
                Label(tr("אַפְשְׁרוּ מְחִיקַת הָאַפְּלִיקַצְיָה (5 דַּקּוֹת)"), systemImage: "trash")
            }
            if let removalNote {
                Text(removalNote).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text(tr("מַכְשִׁיר"))
        } footer: {
            Text(tr("\"הַחְלֵף תַּפְקִיד\" מַחֲזִיר אֶת הַמַּכְשִׁיר לְמָסַךְ \"מִי מִשְׁתַּמֵּשׁ בַּמַּכְשִׁיר?\" — לְמָשָׁל לְהָפֹךְ מַכְשִׁיר הוֹרֶה בַּחֲזָרָה לְמַכְשִׁיר יֶלֶד. בְּמַכְשִׁיר יֶלֶד הַמְּחִיקָה חֲסוּמָה; הַכַּפְתּוֹר פּוֹתֵחַ חַלּוֹן קָצָר לְהָסָרָה אֲמִתִּית."))
        }
        .glassRows()
        .confirmationDialog(tr("לַחֲזֹר לְמָסַךְ בְּחִירַת הַתַּפְקִיד?"),
                            isPresented: $showRolePickerConfirm, titleVisibility: .visible) {
            Button(tr("חֲזֹר לִבְחִירָה")) {
                settings.sessionUnlocked = false   // re-lock the gate after a role switch
                // Clear the child binding so re-picking "child" starts a FRESH scan
                // instead of silently dropping back into the previously-bound kid.
                settings.joinedChildID = nil
                settings.pendingJoinPayload = nil
                settings.justDisconnected = false
                // Also clear the active profile: it lives in the STANDARD defaults
                // and is the evidence healLostChildRoleIfNeeded uses to restore a
                // child role. Left set, the heal would instantly revert this
                // deliberate switch and bounce the device straight back to play.
                ProfileStore.shared.signOutCurrentProfile()
                settings.deviceRole = .unset
                dismiss()
            }
            Button(tr("בִּטּוּל"), role: .cancel) {}
        } message: {
            Text(tr("הַמַּכְשִׁיר יַחֲזֹר לְמָסַךְ בְּחִירַת הַתַּפְקִיד. הַנְּתוּנִים בֶּעָנָן נִשְׁמָרִים — אֶפְשָׁר לִבְחֹר יֶלֶד וְלִסְרֹק שׁוּב, אוֹ לְהִשָּׁאֵר הוֹרֶה."))
        }
        .glassRows()
    }

    private var privacySection: some View {
        Section {
            Button {
                exportURL = DataExporter.writeExportFile()
            } label: {
                Label(tr("ייצוא הנתונים שלי (JSON)"), systemImage: "square.and.arrow.up")
            }
            if let url = exportURL {
                ShareLink(item: url) {
                    Label(tr("שתף את קובץ הייצוא"), systemImage: "doc.badge.arrow.up")
                        .font(.subheadline)
                }
            }
            Button {
                showResetDeviceConfirm = true
            } label: {
                Label(tr("אפס מכשיר זה"), systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                if deleting {
                    HStack { ProgressView(); Text(tr("מוחק…")) }
                } else {
                    Label(tr("מחק את כל הנתונים שלי"), systemImage: "trash.fill")
                }
            }
            .disabled(deleting)
        } header: {
            Text(tr("פרטיות ונתונים"))
        } footer: {
            Text(tr("ייצוא מפיק קובץ JSON עם כל הפרופילים, ההתקדמות וההיסטוריה.\n\n‏\"אפס מכשיר זה\" מנקה את המכשיר לגמרי (מנותק, בלי קוד, בלי נתונים מקומיים) אבל משאיר את המשפחה בענן.\n\n‏\"מחק את כל הנתונים\" מוחק לצמיתות גם מהמכשיר וגם מהענן — לא ניתן לשחזר."))
        }
        .glassRows()
        .confirmationDialog(tr("לאפס את המכשיר הזה?"),
                            isPresented: $showResetDeviceConfirm, titleVisibility: .visible) {
            Button(tr("אפס מכשיר"), role: .destructive) {
                HouseholdManager.shared.resetThisDevice()
                dismiss()
            }
            Button(tr("בטל"), role: .cancel) {}
        } message: {
            Text(tr("המכשיר יחזור למצב התחלתי: מנותק, בלי קוד הורה, בלי נתונים מקומיים. המשפחה וההתקדמות בענן יישמרו — אפשר להתחבר מחדש בכל עת."))
        }
        .confirmationDialog(tr("למחוק את כל הנתונים לצמיתות?"),
                            isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button(tr("מחק הכול"), role: .destructive) { Task { await deleteEverything() } }
            Button(tr("בטל"), role: .cancel) {}
        } message: {
            Text(tr("פעולה זו תמחק את כל הילדים, ההתקדמות וההיסטוריה מהמכשיר ומהענן, ותנתק את החשבון. לא ניתן לבטל."))
        }
        .glassRows()
    }

    private func deleteEverything() async {
        deleting = true
        // Order matters: wipe the cloud data first (Firestore rules need a valid
        // auth session), THEN delete the auth account itself (App Store 5.1.1(v)),
        // then clear local state and sign out.
        await HouseholdManager.shared.deleteAllData()
        await auth.deleteAccount()
        DataExporter.wipeLocalData()
        ProgressStore.shared.resetAll()
        auth.signOut()
        // Wipe the Keychain too — it survives an app delete/reinstall, so without
        // this the parent code lingers. Reset the PIN flags so the gate returns to
        // "create a code" instead of locking the parent out asking for a gone code.
        PINManager.shared.deletePIN()
        settings.hasSetParentPIN = false
        settings.faceIDForParentGate = false
        deleting = false
        dismiss()
    }

    private var pinSection: some View {
        Section {
            Button {
                showChangePIN = true
            } label: {
                Label(tr("שנה קוד הורה"), systemImage: "key.fill")
            }
            if PINManager.shared.biometryAvailable {
                Toggle(isOn: $settings.faceIDForParentGate) {
                    Label(tr("פתח עם Face ID / Touch ID"), systemImage: "faceid")
                }
            }
        } header: {
            Text(tr("אבטחה"))
        } footer: {
            Text(tr("הקוד נשמר מוצפן (hash) במכשיר ולא בטקסט גלוי."))
        }
        .glassRows()
    }

    private var versionSection: some View {
        Section {
            // Rani: "מה חדש" pops once per version and is gone. A parent who
            // dismissed it while busy had no way back to it — so it lives here,
            // next to the version it describes, and can be re-opened any time.
            Button {
                Haptic.light()
                showWhatsNew = true
            } label: {
                Label(tr("מָה חָדָשׁ בַּגִּרְסָה הַזּוֹ ✨"), systemImage: "sparkles")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .disabled(WhatsNewContent.items(for: WhatsNewContent.currentVersion) == nil)

            VStack(spacing: 3) {
                Text(tr("טופי"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(AppInfo.versionLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
        .glassRows()
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(onDone: { showWhatsNew = false })
        }
        .glassRows()
    }
}

struct ChangePINView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.dismiss) private var dismiss
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("קוד חדש")) {
                    SecureField(tr("4 ספרות"), text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField(tr("אמת קוד"), text: $confirmPIN)
                        .keyboardType(.numberPad)
                }
                .glassRows()
                if let error = error {
                    Section { Text(error).foregroundStyle(.red) }
                    .glassRows()
                }
                Section {
                    Button(tr("שמור")) { save() }
                        .disabled(newPIN.count != 4 || confirmPIN.count != 4)
                }
                .glassRows()
            }
            .glassForm()
            .navigationTitle(tr("שינוי קוד הורה"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("ביטול")) { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard newPIN.count == 4, newPIN.allSatisfy(\.isNumber) else {
            error = tr("הקוד חייב להיות בדיוק 4 ספרות")
            return
        }
        guard newPIN == confirmPIN else {
            error = tr("הקודים לא תואמים")
            return
        }
        settings.pin = newPIN          // keep legacy mirror for migration safety
        PINManager.shared.setPIN(newPIN)
        settings.hasSetParentPIN = true
        HouseholdManager.shared.setHouseholdPIN(PINManager.shared.makeBlob(newPIN))  // share family-wide
        dismiss()
    }
}

#Preview {
    ParentSettingsView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(AuthManager.shared)
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .app)
}
