import SwiftUI

/// ⏱ The daily screen-time ceiling, asked up front (approved mockup):
/// the last step of creating a child, and a one-time card on the parent home
/// for families that already exist. Both write the same per-child field the
/// screen-time editor (`ChildScreenTimeView`) writes — `Profile.dailyCapMinutes`
/// through `ProfileStore` → `HouseholdManager.upsertChild` → the child's device.
///
/// Parent-side copy: plain Hebrew, no niqqud (Rani).
enum DailyCapChoice {
    /// The five choices, in the order the mockup lays them out. 0 = no limit —
    /// the same value `ChildScreenTimeView` stores when its toggle is off.
    static let options: [Int] = [30, 60, 90, 120, 0]
    /// Preselected for a new child.
    static let defaultMinutes = 60

    /// "30 דק׳" / "שעה" / "שעה וחצי" / "שעתיים" / "ללא הגבלה" — and any other
    /// value a parent typed in the screen-time editor, in minutes.
    static func label(_ minutes: Int) -> String {
        switch minutes {
        case ...0: return tr("ללא הגבלה")
        case 60:   return tr("שעה")
        case 90:   return tr("שעה וחצי")
        case 120:  return tr("שעתיים")
        default:   return tr("\(minutes) דק׳")
        }
    }

    /// What the child is held to right now, as one of the stored values
    /// (0 = no limit) — the per-child value, else the device-global fallback.
    static func current(for profile: Profile, settings: ParentSettings) -> Int {
        let cap = profile.resolvedDailyCap(globalEnabled: settings.dailyCapEnabled,
                                           globalMax: settings.maxMinutesPerDay)
        return cap.enabled ? cap.minutes : 0
    }

    /// The grade line without niqqud (parent side) — keeps the maqaf
    /// ("גן טרום־חובה"), unlike `Question.stripNiqqud`.
    static func gradeLine(_ profile: Profile) -> String? {
        guard profile.grade != nil else { return nil }
        let name = Profile.gradeDisplayName(profile.effectiveGrade)
        return String(String.UnicodeScalarView(name.unicodeScalars.filter { s in
            let v = s.value
            guard (0x0591...0x05C7).contains(v) else { return true }
            return v == 0x05BE || v == 0x05C0 || v == 0x05C3 || v == 0x05C6   // maqaf, paseq, sof pasuq, nun hafukha
        }))
    }
}

// MARK: - Create child · last step

/// The last step of creating a child: how much screen time a day they can earn.
struct DailyCapStepView: View {
    let profile: Profile
    @Binding var minutes: Int
    var onContinue: () -> Void

    @ObservedObject private var display = DisplayGeometry.shared

    private var isGirl: Bool { profile.gender == .girl }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Text(tr("יצירת ילד · שלב אחרון"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, AppSpacing.md)

                ProfileAvatarView(profile: profile, size: display.isShort ? 76 : 104)

                Text(isGirl ? tr("כמה זמן מסך ביום \(profile.name) יכולה להרוויח?")
                            : tr("כמה זמן מסך ביום \(profile.name) יכול להרוויח?"))
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                          spacing: 10) {
                    ForEach(DailyCapChoice.options.filter { $0 > 0 }, id: \.self) { m in
                        pill(m)
                    }
                }
                pill(0)

                tipBox

                // The haptic + cheer come from the editor's save().
                Button(action: onContinue) {
                    Text(tr("המשך"))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.gold, radius: 18)
                        .glow(AppColor.starGold, radius: 10)
                }
                .buttonStyle(.juicy)
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxl)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .app)
    }

    private func pill(_ m: Int) -> some View {
        let selected = minutes == m
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { minutes = m }
        } label: {
            HStack(spacing: 6) {
                if m == 0 { Text("♾️").font(.system(size: 17)) }
                Text(DailyCapChoice.label(m))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(AppColor.successMint)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassPane(radius: AppRadius.medium, strength: selected ? 0.30 : 0.12, shadow: false)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(selected ? AppColor.successMint : .white.opacity(0.2),
                            lineWidth: selected ? 2.5 : 1)
            )
        }
        .buttonStyle(.juicy)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var tipBox: some View {
        Text(isGirl
             ? tr("💡 \(profile.name) מרוויחה זמן רק על תשובות נכונות. זו התקרה היומית, ואפשר לשנות בכל רגע בהגדרות של \(profile.name).")
             : tr("💡 \(profile.name) מרוויח זמן רק על תשובות נכונות. זו התקרה היומית, ואפשר לשנות בכל רגע בהגדרות של \(profile.name)."))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .glassPane(radius: 16, tint: AppColor.starGold, shadow: false)
    }
}

/// DEMO_SCREEN=dailycapstep — the step as the parent sees it, with a demo child.
struct DailyCapStepDemo: View {
    let profile: Profile
    @State private var minutes = DailyCapChoice.defaultMinutes

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                SparkleField(count: 12, size: 11)
                DailyCapStepView(profile: profile, minutes: $minutes) {}
            }
            .navigationTitle(tr("פְּרוֹפִיל חָדָשׁ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(tr("חזרה")) {} }
            }
        }
        .environment(\.layoutDirection, .app)
    }
}

// MARK: - Parent home · one-time card

/// "⏱ כמה זמן מסך ביום?" — once, for families created before the create-child
/// step existed. A row per child with the current ceiling; "שמירה" writes every
/// child's choice and retires the card for good.
struct DailyCapSetupCard: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var settings: ParentSettings
    /// The children, in the dashboard's order.
    let children: [Profile]

    /// Only the rows the parent touched; the rest show their current value.
    @State private var drafts: [UUID: Int] = [:]

    private func value(for p: Profile) -> Int {
        drafts[p.id] ?? DailyCapChoice.current(for: p, settings: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("⏱ כמה זמן מסך ביום?"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr("הגדירו לכל ילד כמה זמן הוא יכול להרוויח ביום"))
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            VStack(spacing: 8) {
                ForEach(children) { p in row(p) }
            }

            Button(action: save) {
                Text(tr("שמירה"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassFill(AppGradient.gold, radius: 16)
            }
            .buttonStyle(.juicy)
        }
        .padding(AppSpacing.md)
        .glassPane(radius: 20, tint: AppColor.starGold)
        .environment(\.layoutDirection, .app)
    }

    private func row(_ p: Profile) -> some View {
        let current = value(for: p)
        // A value typed in the screen-time editor (e.g. 45) stays on the list
        // until the parent picks another.
        let choices = DailyCapChoice.options.contains(current)
            ? DailyCapChoice.options : [current] + DailyCapChoice.options
        return HStack(spacing: 10) {
            ProfileAvatarView(profile: p, size: 38, headItemsOnly: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let grade = DailyCapChoice.gradeLine(p) {
                    Text(grade)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Menu {
                ForEach(choices, id: \.self) { m in
                    Button {
                        Haptic.light()
                        drafts[p.id] = m
                    } label: {
                        if m == current {
                            Label(DailyCapChoice.label(m), systemImage: "checkmark")
                        } else {
                            Text(DailyCapChoice.label(m))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(DailyCapChoice.label(current))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.16)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassInset(radius: 14)
    }

    private func save() {
        for p in children {
            let v = value(for: p)
            // The parent confirmed this number — store it on the child even if
            // it equals the inherited one: the child's device has its own
            // global setting, and only the per-child value reaches it.
            guard var fresh = profiles.profiles.first(where: { $0.id == p.id }),
                  fresh.dailyCapMinutes != v else { continue }
            fresh.dailyCapMinutes = v
            profiles.update(fresh)   // → HouseholdManager.upsertChild → the child's device
        }
        Haptic.success()
        withAnimation(.easeInOut(duration: 0.25)) { settings.dailyCapCardDone = true }
    }
}
