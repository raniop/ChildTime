import SwiftUI
import PhotosUI

/// Sheet for creating or editing a profile. Lets the kid pick name, gender,
/// age, photo, and an initial avatar preset.
struct ProfileEditorView: View {
    enum Mode: Equatable {
        case create
        case edit(Profile)
    }

    let mode: Mode
    var onSave: (Profile) -> Void
    var onDelete: ((Profile) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profiles: ProfileStore

    @State private var name: String = ""
    @State private var gender: ChildGender? = nil
    @State private var age: ChildAge = .grade1
    @State private var photoData: Data? = nil
    @State private var avatarPresetID: String = AvatarPreset.defaultID(for: nil)
    /// The child's chosen 3D character (picked in the shop). Carried through the
    /// editor so the preview shows the REAL avatar and saving never wipes it.
    @State private var character3DID: String? = nil
    @State private var grade: Int? = nil
    @State private var interests: Set<String> = []
    @State private var learningLevel: LearningLevel = .developing
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showPicker = false
    @State private var pendingCrop: PendingCrop? = nil
    @State private var showDeleteConfirm = false

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }
    private var existingID: UUID? {
        if case .edit(let p) = mode { return p.id }
        return nil
    }
    /// A grade/gan choice is REQUIRED (Rani): it drives the curriculum-aligned
    /// content and the automatic September promotion. Only when the parent is
    /// the one editing — a child device can't edit learning fields anyway.
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (!canEditLearning || grade != nil)
    }

    /// Age + learning level are difficulty-affecting → editable only from a real
    /// PARENT device, never on a child device or while the parent's phone is in
    /// Kid Mode (where a child is using it).
    private var canEditLearning: Bool {
        ParentSettings.shared.deviceRole == .parent && !KidModeManager.shared.active
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.dreamy.ignoresSafeArea()
                SparkleField(count: 16, size: 12)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        livePreview
                            .padding(.top, AppSpacing.md)

                        nameField

                        genderRow

                        // Age + learning level drive question difficulty — so they
                        // are PARENT-ONLY. Hidden on a child device (and in Kid Mode)
                        // so a kid can't lower their own age to get easier questions.
                        if canEditLearning {
                            ageRow

                            gradeRow

                            learningLevelRow
                        }

                        interestsSection

                        if isEdit, let id = existingID {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("מְחַק פְּרוֹפִיל", systemImage: "trash")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.25), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, AppSpacing.md)
                            .confirmationDialog(
                                "לִמְחוֹק אֶת הַפְּרוֹפִיל שֶׁל \(name)?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("מְחַק", role: .destructive) {
                                    if case .edit(let p) = mode {
                                        onDelete?(p)
                                    }
                                    _ = id  // silence unused
                                }
                                Button("בַּטֵּל", role: .cancel) {}
                            }
                        }

                        Text("טופי · \(AppInfo.versionLine)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.lg)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(isEdit ? "עֲרוֹךְ פְּרוֹפִיל" : "פְּרוֹפִיל חָדָשׁ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("בַּטֵּל") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("שְׁמוֹר") { save() }
                        .disabled(!canSave)
                        .fontWeight(.bold)
                }
            }
            .onAppear { hydrateFromMode() }
        }
    }

    // MARK: - Sub-views

    private var livePreview: some View {
        let preview = Profile(
            id: existingID ?? UUID(),
            name: name.isEmpty ? "—" : name,
            gender: gender,
            age: age,
            photoData: photoData,
            avatarPresetID: avatarPresetID,
            character3DID: character3DID
        )
        return VStack(spacing: 10) {
            // Shows the child's chosen 3D character (picked in the shop) — no
            // more profile photo.
            ProfileAvatarView(profile: preview, size: 130)
            Text(preview.name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("שֵׁם")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            RTLTextField(placeholder: "שֵׁם הַיֶּלֶד/ה", text: $name, textColor: .white)
                .frame(height: 28)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    private var genderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("יֶלֶד אוֹ יַלְדָּה?")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: AppSpacing.md) {
                ForEach(ChildGender.allCases) { g in
                    genderOption(g)
                }
            }
        }
    }

    private func genderOption(_ g: ChildGender) -> some View {
        let selected = gender == g
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                gender = g
            }
        } label: {
            HStack(spacing: 8) {
                Text(g.emoji).font(.system(size: 22))
                Text(g.displayName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(selected ? 0.28 : 0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(selected ? AppColor.successMint : .white.opacity(0.2),
                            lineWidth: selected ? 2.5 : 1)
            )
            .glow(selected ? AppColor.successMint : .clear, radius: selected ? 8 : 0)
        }
        .buttonStyle(.juicy)
    }

    private var ageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("בֶּן/בַּת כַּמָּה?")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 6) {
                ForEach(ChildAge.allCases) { a in
                    ageOption(a)
                }
            }
        }
    }

    private func ageOption(_ a: ChildAge) -> some View {
        let selected = age == a
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                age = a
                // Keep the grade choice consistent with the bracket: a gan pick
                // makes no sense for an older child and vice versa.
                if let g = grade {
                    if a == .preK && g > 0 { grade = nil }
                    if a != .preK && g < 1 { grade = nil }
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text(a.emoji).font(.system(size: 26))
                Text(a.label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(selected ? 0.26 : 0.10), in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(selected ? AppColor.successMint : .white.opacity(0.18),
                            lineWidth: selected ? 2.2 : 1)
            )
        }
        .buttonStyle(.juicy)
    }

    /// REQUIRED grade picker (drives curriculum content + the automatic
    /// September promotion). preK → gan types; otherwise כיתות א׳–ח׳.
    private var gradeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(age == .preK ? "בְּאֵיזֶה גַּן?" : "בְּאֵיזוֹ כִּתָּה?")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            if age == .preK {
                HStack(spacing: 6) {
                    gradeOption(-1, label: "טְרוֹם־חוֹבָה", emoji: "🧸")
                    gradeOption(0, label: "גַּן חוֹבָה", emoji: "🎒")
                }
            } else {
                let letters = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳"]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(1...8, id: \.self) { g in
                        gradeOption(g, label: letters[g - 1], emoji: nil)
                    }
                }
            }
            if grade == nil {
                Text("חוֹבָה לִבְחֹר — כָּךְ טוֹפִי מַתְאִים אֶת הַשְּׁאֵלוֹת לַתָּכְנִית שֶׁל מִשְׂרַד הַחִנּוּךְ, וְכָל 1 בְּסֶפְּטֶמְבֶּר עוֹלִים כִּתָּה אוֹטוֹמָטִית 🎉")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
            }
        }
    }

    private func gradeOption(_ g: Int, label: String, emoji: String?) -> some View {
        let selected = grade == g
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { grade = g }
        } label: {
            VStack(spacing: 3) {
                if let emoji { Text(emoji).font(.system(size: 22)) }
                Text(label)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(selected ? 0.26 : 0.10), in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(selected ? AppColor.successMint : .white.opacity(0.18),
                            lineWidth: selected ? 2.2 : 1)
            )
        }
        .buttonStyle(.juicy)
    }

    private var learningLevelRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("רָמַת לְמִידָה הַתְחָלָתִית")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 6) {
                ForEach(LearningLevel.allCases) { level in
                    let selected = learningLevel == level
                    Button {
                        Haptic.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { learningLevel = level }
                    } label: {
                        VStack(spacing: 4) {
                            Text(level.emoji).font(.system(size: 22))
                            Text(level.displayName)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.white.opacity(selected ? 0.26 : 0.10), in: RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(selected ? AppColor.successMint : .white.opacity(0.18), lineWidth: selected ? 2.2 : 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("תְּחוּמֵי עִנְיָן (לַפִּיד הֶחָכָם)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(InterestCatalog.all) { interest in
                    let selected = interests.contains(interest.id)
                    Button {
                        Haptic.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selected { interests.remove(interest.id) } else { interests.insert(interest.id) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(interest.emoji)
                            Text(interest.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(selected ? 0.26 : 0.10), in: Capsule())
                        .overlay(Capsule().stroke(selected ? AppColor.starGold : .white.opacity(0.18),
                                                  lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
        }
    }

    private var avatarPresetGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🙂 בְּחַר פַּרְצוּף")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 12)], spacing: 12) {
                ForEach(AvatarPreset.all) { preset in
                    presetOption(preset)
                }
            }
        }
    }

    private func presetOption(_ preset: AvatarPreset) -> some View {
        let selected = avatarPresetID == preset.id
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                avatarPresetID = preset.id
            }
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [preset.topColor, preset.bottomColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 70, height: 70)
                Text(preset.emoji).font(.system(size: 36))
            }
            .overlay(
                Circle().stroke(
                    selected ? AppColor.starGold : .white.opacity(0.3),
                    lineWidth: selected ? 3 : 1.5
                )
            )
            .scaleEffect(selected ? 1.08 : 1.0)
            .glow(selected ? AppColor.starGold : .clear, radius: selected ? 10 : 0)
        }
        .buttonStyle(.juicy)
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📷 אוֹ הַעֲלֵה תְּמוּנָה (אוֹפְּצִיוֹנָלִי)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 10) {
                Button {
                    showPicker = true
                } label: {
                    Label(photoData == nil ? "בְּחַר תְּמוּנָה" : "הַחְלֵף תְּמוּנָה",
                          systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.juicy)
                if photoData != nil {
                    Button(role: .destructive) {
                        photoData = nil
                    } label: {
                        Label("הָסֵר", systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.25), in: Capsule())
                    }
                    .buttonStyle(.juicy)
                }
            }
        }
    }

    // MARK: - Actions

    private func hydrateFromMode() {
        if case .edit(let p) = mode {
            name = p.name
            gender = p.gender
            age = p.age
            photoData = p.photoData
            avatarPresetID = p.avatarPresetID
            character3DID = p.character3DID
            // Show the AUTO-ADVANCED grade (a year may have passed since it was
            // stored) — saving re-stamps the school-year anchor with this value.
            grade = p.grade != nil ? p.effectiveGrade : nil
            interests = Set(p.interests)
            learningLevel = p.learningLevel
        } else {
            // Sensible defaults for the create flow
            avatarPresetID = AvatarPreset.defaultID(for: nil)
        }
    }

    private func save() {
        guard canSave else { return }
        var p = Profile(
            id: existingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            gender: gender,
            age: age,
            photoData: photoData,
            avatarPresetID: avatarPresetID,
            character3DID: character3DID,
            createdAt: .now,
            grade: grade,
            // Anchor the September auto-advance to the year this grade was picked.
            gradeSchoolYear: grade != nil ? Profile.schoolYear() : nil,
            interests: Array(interests),
            learningLevel: learningLevel
        )
        // PRESERVE everything this editor doesn't edit — building a fresh
        // Profile used to silently reset the parent's topic choices, per-topic
        // difficulty, daily cap and the child's play code on EVERY edit.
        if case .edit(let original) = mode {
            p.createdAt = original.createdAt
            p.difficultyByTopic = original.difficultyByTopic
            p.dailyCapMinutes = original.dailyCapMinutes
            p.enabledTopics = original.enabledTopics
            p.topicsVersion = original.topicsVersion
            p.playPIN = original.playPIN
            // A child device (no learning fields shown) keeps the stored grade.
            if !canEditLearning {
                p.grade = original.grade
                p.gradeSchoolYear = original.gradeSchoolYear
                p.gradeSetByChild = original.gradeSetByChild
            }
            // A parent-side save is a confirmation — clears the "child picked
            // this" flag the dashboard warns about. (Fresh Profile defaults it
            // to false, so nothing to do — noted for clarity.)
        }
        Haptic.success()
        SoundPlayer.shared.play(.companionCheer)
        onSave(p)
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        // Don't auto-crop — hand the picked image to the interactive cropper.
        await MainActor.run { pendingCrop = PendingCrop(image: image) }
    }
}

/// Wrapper so the picked image can drive an `item:`-based cover.
private struct PendingCrop: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - UIImage helper

private extension UIImage {
    func resizedSquareForAvatar(maxEdge: CGFloat) -> UIImage {
        let shortSide = min(size.width, size.height)
        let crop = CGRect(
            x: (size.width  - shortSide) / 2,
            y: (size.height - shortSide) / 2,
            width: shortSide, height: shortSide
        )
        let cropped: UIImage = {
            guard let cg = cgImage?.cropping(to: crop) else { return self }
            return UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
        }()
        let target = CGSize(width: maxEdge, height: maxEdge)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
