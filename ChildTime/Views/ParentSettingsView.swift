import SwiftUI
import FamilyControls

struct ParentSettingsView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var subs: SubscriptionManager
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showChangePIN = false
    @State private var showSignIn = false
    @State private var showPaywall = false
    @State private var showDashboard = false
    @State private var showFamilyLinking = false
    @State private var exportURL: URL?
    @State private var showDeleteAllConfirm = false
    @State private var deleting = false
    @State private var testPushMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                premiumSection
                dashboardSection
                profileSection
                authorizationSection
                syncSection
                notificationsSection
                ageSection
                rewardSection
                smartFeedSection
                dailyCapSection
                penaltySection
                soundsSection
                topicsSection
                appsSection
                pinSection
                privacySection
            }
            .navigationTitle("הגדרות הורה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סיום") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
            .onChange(of: pickerSelection) { _, new in
                settings.activitySelectionData = SelectionStorage.encode(new)
                shields.applyShield(from: new)
            }
            .onAppear {
                pickerSelection = SelectionStorage.decode(settings.activitySelectionData)
            }
            .sheet(isPresented: $showChangePIN) {
                ChangePINView()
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
                    .environmentObject(auth)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subs)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showFamilyLinking) {
                FamilyLinkingView()
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .sheet(isPresented: $showDashboard) {
                ParentDashboardView()
                    .environmentObject(profiles)
                    .environmentObject(settings)
                    .environmentObject(auth)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
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
                        Text("מבט-על על המשפחה")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("\(profiles.profiles.count) פרופילים • זמן, ניקוד, ואיפוסים")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var premiumSection: some View {
        Section {
            if subs.isPremium {
                // Active subscriber
                HStack(spacing: 12) {
                    Text("👑").font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("טופי+ פעיל")
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
                    Label("נהל מנוי ב-Apple ID", systemImage: "gear")
                }
            } else {
                // Upsell card
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Text("👑").font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("שדרג ל-טופי+")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text("כל הנושאים, כל העולמות, פרופילים לכל ילד")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await subs.restorePurchases() }
                } label: {
                    Label("שחזר רכישה קיימת", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
            }
        } header: {
            Text("מנוי")
        } footer: {
            if !subs.isPremium {
                Text("ניסיון 7 ימים חינם במסלול השנתי. ניתן לבטל בכל עת בהגדרות Apple ID.")
                    .font(.caption2)
            } else {
                EmptyView()
            }
        }
    }

    private var premiumStatusSubtitle: String {
        switch subs.subscriptionState {
        case .active(let expires?, let willRenew):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.locale = Locale(identifier: "he_IL")
            return willRenew
                ? "מתחדש ב-\(df.string(from: expires))"
                : "פעיל עד \(df.string(from: expires))"
        case .active(nil, _):
            return "רכישה לכל החיים ✨"
        case .inTrial(let expires):
            let df = DateFormatter()
            df.dateStyle = .medium
            df.locale = Locale(identifier: "he_IL")
            return "ניסיון חינם עד \(df.string(from: expires))"
        default:
            return ""
        }
    }

    private var authorizationSection: some View {
        Section("הרשאות") {
            HStack {
                Image(systemName: shields.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(shields.isAuthorized ? .green : .orange)
                VStack(alignment: .leading) {
                    Text(shields.isAuthorized ? "Family Controls מאושר" : "צריך אישור")
                        .font(.headline)
                    if let err = shields.authorizationError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    } else if !shields.isAuthorized {
                        Text("בלי זה לא נוכל לחסום אפליקציות")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !shields.isAuthorized {
                    Button("בקש") {
                        Task { await shields.requestAuthorizationIfNeeded() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var syncSection: some View {
        Section("סנכרון בין מכשירים") {
            if auth.isSignedIn {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.displayName ?? auth.email ?? "מחובר")
                            .font(.headline)
                        if let email = auth.email, email != auth.displayName {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let p = auth.provider {
                            Text(p == .apple ? "דרך Apple" : "דרך Google")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                Button {
                    showFamilyLinking = true
                } label: {
                    Label("קִישּׁוּר מִשְׁפָּחָה (QR / קוֹד)", systemImage: "qrcode")
                }
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Label("התנתק", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("התחבר כדי שההתקדמות של הילד תישמר גם ב-iPad וגם ב-iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showSignIn = true
                    } label: {
                        Label("התחבר עם Apple או Google", systemImage: "icloud.and.arrow.up")
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
    }

    @StateObject private var push = PushManager.shared

    private var notificationsSection: some View {
        Section {
            if push.authorized {
                Label("התראות פעילות", systemImage: "bell.badge.fill")
                    .foregroundStyle(AppColor.successMint)
            } else {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Label("הפעל התראות חיות", systemImage: "bell.fill")
                }
            }
            Button {
                Task { testPushMessage = await push.sendTestPush() }
            } label: {
                Label("שלח התראת בדיקה", systemImage: "paperplane.fill")
            }
            if let testPushMessage {
                Text(testPushMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("התראות להורה")
        } footer: {
            Text("קבלו עדכון כשהילד מתחיל ומסיים לשחק, פותח רצף, זוכה בגלגל מזל או מגלה תחום חדש — וגם דוח שבועי. ההתראות נשלחות בין המכשירים בבית. \"שלח התראת בדיקה\" שולח התראה אליכם עכשיו כדי לוודא שהכול עובד.")
        }
        .task { await push.refreshAuthorizationStatus() }
    }

    private var ageSection: some View {
        Section("גיל הילד") {
            Picker("גיל", selection: Binding(
                get: { settings.childAge },
                set: { newAge in
                    settings.childAge = newAge
                }
            )) {
                ForEach(ChildAge.allCases) { age in
                    Text("\(age.emoji)  \(age.label) — \(age.description)").tag(age)
                }
            }
            Button {
                settings.applyAgeDefaults(settings.childAge)
            } label: {
                Label("התאם קושי לפי גיל", systemImage: "wand.and.stars")
            }
            .foregroundStyle(.tint)
        }
    }

    private var profileSection: some View {
        Section("פרופיל הילד") {
            HStack(spacing: 14) {
                ChildAvatarView(size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.childName.isEmpty ? "ללא שם" : settings.childName)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    if profiles.profiles.count > 1 {
                        Text("\(profiles.profiles.count) פרופילים במשפחה")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("הקש על התמונה כדי להחליף תמונה")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)

            RTLTextField(placeholder: "שם הילד", text: $settings.childName,
                         onCommit: { profiles.syncBackFromSettings() })
                .frame(height: 24)

            Button {
                profiles.syncBackFromSettings()
                profiles.signOutCurrentProfile()
            } label: {
                Label("החלף פרופיל", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
    }

    private var rewardSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(AppColor.successMint)
                Text("כל \(settings.batchAnswers) תשובות נכונות = \(settings.batchMinutes) דקות משחק")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
            }
            Stepper(
                "תשובות נכונות לתגמול: \(settings.batchAnswers)",
                value: $settings.batchAnswers,
                in: 1...30
            )
            Stepper(
                "דקות משחק לתגמול: \(settings.batchMinutes)",
                value: $settings.batchMinutes,
                in: 1...30
            )
            Stepper(
                "שאלות בכל סבב: \(settings.questionsPerSession)",
                value: $settings.questionsPerSession,
                in: 15...30
            )
        } header: {
            Text("תגמול")
        } footer: {
            Text("הילד מרוויח \(settings.batchMinutes) דקות משחק על כל \(settings.batchAnswers) תשובות נכונות. אפשר לשנות את שני המספרים. ברירת המחדל: 10 תשובות = 4 דקות.")
        }
    }

    private var smartFeedSection: some View {
        Section {
            Stepper(
                "גלגל מזל כל \(settings.questionsPerWheel) שאלות",
                value: $settings.questionsPerWheel,
                in: 5...50,
                step: 5
            )
        } header: {
            Text("פיד למידה חכם")
        } footer: {
            Text("ב\"הרפתקה חכמה\" המערכת בונה לכל ילד פיד אישי: 80% מהנושאים שהוא אוהב ו-20% תחומים חדשים לגילוי. הפיד משתפר אחרי כל שאלה. כל \(settings.questionsPerWheel) שאלות הילד מרוויח סיבוב חינם בגלגל המזל.")
        }
    }

    private var dailyCapSection: some View {
        Section {
            Toggle("הגבל זמן יומי", isOn: $settings.dailyCapEnabled)
            if settings.dailyCapEnabled {
                Stepper(
                    "מקסימום \(settings.maxMinutesPerDay) דק' ליום",
                    value: $settings.maxMinutesPerDay,
                    in: 10...240,
                    step: 5
                )
                HStack {
                    Text("נצבר היום")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(progress.minutesEarnedToday) / \(settings.maxMinutesPerDay) דק'")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(progress.minutesEarnedToday >= settings.maxMinutesPerDay ? .orange : .primary)
                }
            }
        } header: {
            Text("מגבלת זמן יומית")
        } footer: {
            Text(settings.dailyCapEnabled
                ? "גם אם הילד עונה נכון על הרבה שאלות, הוא לא ירוויח יותר מ-\(settings.maxMinutesPerDay) דקות ביום. המונה מתאפס כל יום בחצות."
                : "כבוי. הילד יכול לצבור כמה דקות שירצה.")
        }
    }

    private var penaltySection: some View {
        let perMistake = progress.mistakePenaltyMinutes(minutesPerCorrect: settings.minutesPerCorrectAnswer)
        return Section {
            Toggle("טעויות עולות זמן", isOn: $settings.penaltyEnabled)
        } header: {
            Text("טעויות ולולאת תיקון")
        } footer: {
            Text(settings.penaltyEnabled
                ? "כל טעות מורידה \(perMistake) דק' (חצי מתגמול תשובה נכונה) — אבל הילד יכול להחזיר את הזמן מיד: תשובה נכונה ונקייה בשאלה הבאה מחזירה את כל הזמן שירד. אף פעם לא מוצג לילד \"טעית\" או \"הפסדת\"."
                : "כבוי. הילד לא יאבד זמן גם אם יטעה הרבה.")
        }
    }

    private var soundsSection: some View {
        Section {
            Toggle("צלילים פעילים", isOn: $settings.soundsEnabled)
        } header: {
            Text("צלילים")
        } footer: {
            Text("הצלילים באפליקציה רכים ומשמשים כפידבק על תשובות נכונות / שגויות. ניתן לכבות אותם לגמרי.")
        }
    }

    private var topicsSection: some View {
        Section("נושאי שאלות") {
            ForEach(Topic.allCases) { topic in
                topicRow(topic)
            }
        }
    }

    private func topicRow(_ topic: Topic) -> some View {
        let binding = Binding<Bool>(
            get: { settings.enabledTopics.contains(topic) },
            set: { isOn in
                if isOn { settings.enabledTopics.insert(topic) }
                else { settings.enabledTopics.remove(topic) }
            }
        )
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: binding) {
                HStack {
                    Text(topic.emoji)
                    Text(topic.displayName)
                }
            }
            if settings.enabledTopics.contains(topic) {
                Picker("רמת קושי", selection: Binding(
                    get: { settings.difficulty(for: topic) },
                    set: { settings.setDifficulty($0, for: topic) }
                )) {
                    ForEach(Difficulty.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var appsSection: some View {
        Section("אפליקציות לחסום") {
            Button {
                showAppPicker = true
            } label: {
                HStack {
                    Image(systemName: "app.badge.fill")
                    Text("בחר אפליקציות")
                    Spacer()
                    let count = pickerSelection.applicationTokens.count
                        + pickerSelection.categoryTokens.count
                    if count > 0 {
                        Text("\(count) נבחרו")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.left").foregroundStyle(.secondary)
                }
            }
            if pickerSelection.applicationTokens.isEmpty
                && pickerSelection.categoryTokens.isEmpty {
                Text("עדיין לא בחרת אפליקציות לחסום. בלי בחירה - לא יקרה כלום כשהילד פותח את ה-iPad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button(role: .destructive) {
                    pickerSelection = FamilyActivitySelection()
                } label: {
                    Label("נקה בחירה", systemImage: "trash")
                }
            }
        }
    }

    private var privacySection: some View {
        Section {
            Button {
                exportURL = DataExporter.writeExportFile()
            } label: {
                Label("ייצוא הנתונים שלי (JSON)", systemImage: "square.and.arrow.up")
            }
            if let url = exportURL {
                ShareLink(item: url) {
                    Label("שתף את קובץ הייצוא", systemImage: "doc.badge.arrow.up")
                        .font(.subheadline)
                }
            }
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                if deleting {
                    HStack { ProgressView(); Text("מוחק…") }
                } else {
                    Label("מחק את כל הנתונים שלי", systemImage: "trash.fill")
                }
            }
            .disabled(deleting)
        } header: {
            Text("פרטיות ונתונים")
        } footer: {
            Text("ייצוא מפיק קובץ JSON עם כל הפרופילים, ההתקדמות וההיסטוריה. מחיקה מסירה לצמיתות את כל הנתונים מהמכשיר ומהענן — לא ניתן לשחזר.")
        }
        .confirmationDialog("למחוק את כל הנתונים לצמיתות?",
                            isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("מחק הכול", role: .destructive) { Task { await deleteEverything() } }
            Button("בטל", role: .cancel) {}
        } message: {
            Text("פעולה זו תמחק את כל הילדים, ההתקדמות וההיסטוריה מהמכשיר ומהענן, ותנתק את החשבון. לא ניתן לבטל.")
        }
    }

    private func deleteEverything() async {
        deleting = true
        await HouseholdManager.shared.deleteAllData()
        DataExporter.wipeLocalData()
        ProgressStore.shared.resetAll()
        auth.signOut()
        deleting = false
        dismiss()
    }

    private var pinSection: some View {
        Section {
            Button {
                showChangePIN = true
            } label: {
                Label("שנה קוד הורה", systemImage: "key.fill")
            }
            if PINManager.shared.biometryAvailable {
                Toggle(isOn: $settings.faceIDForParentGate) {
                    Label("פתח עם Face ID / Touch ID", systemImage: "faceid")
                }
            }
        } header: {
            Text("אבטחה")
        } footer: {
            Text("הקוד נשמר מוצפן (hash) במכשיר ולא בטקסט גלוי.")
        }
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
                Section("קוד חדש") {
                    SecureField("4 ספרות", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("אמת קוד", text: $confirmPIN)
                        .keyboardType(.numberPad)
                }
                if let error = error {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button("שמור") { save() }
                        .disabled(newPIN.count != 4 || confirmPIN.count != 4)
                }
            }
            .navigationTitle("שינוי קוד הורה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ביטול") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard newPIN.count == 4, newPIN.allSatisfy(\.isNumber) else {
            error = "הקוד חייב להיות בדיוק 4 ספרות"
            return
        }
        guard newPIN == confirmPIN else {
            error = "הקודים לא תואמים"
            return
        }
        settings.pin = newPIN          // keep legacy mirror for migration safety
        PINManager.shared.setPIN(newPIN)
        settings.hasSetParentPIN = true
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
        .environment(\.layoutDirection, .rightToLeft)
}
