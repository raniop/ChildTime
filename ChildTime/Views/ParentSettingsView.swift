import SwiftUI
import FamilyControls

struct ParentSettingsView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showChangePIN = false

    var body: some View {
        NavigationStack {
            Form {
                authorizationSection
                ageSection
                rewardSection
                topicsSection
                appsSection
                pinSection
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

    private var rewardSection: some View {
        Section("תגמול") {
            Stepper(
                "דקות לכל תשובה נכונה: \(settings.minutesPerCorrectAnswer)",
                value: $settings.minutesPerCorrectAnswer,
                in: 1...10
            )
            Stepper(
                "שאלות בכל סבב: \(settings.questionsPerSession)",
                value: $settings.questionsPerSession,
                in: 3...20
            )
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

    private var pinSection: some View {
        Section("אבטחה") {
            Button {
                showChangePIN = true
            } label: {
                Label("שנה קוד הורה", systemImage: "key.fill")
            }
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
        settings.pin = newPIN
        dismiss()
    }
}

#Preview {
    ParentSettingsView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ShieldManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
