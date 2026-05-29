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
    @State private var grade: Int? = nil
    @State private var interests: Set<String> = []
    @State private var learningLevel: LearningLevel = .developing
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showPicker = false
    @State private var showDeleteConfirm = false

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }
    private var existingID: UUID? {
        if case .edit(let p) = mode { return p.id }
        return nil
    }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

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

                        ageRow

                        learningLevelRow

                        interestsSection

                        avatarPresetGrid

                        photoControls

                        if isEdit, let id = existingID {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("מחק פרופיל", systemImage: "trash")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.25), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, AppSpacing.md)
                            .confirmationDialog(
                                "למחוק את הפרופיל של \(name)?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("מחק", role: .destructive) {
                                    if case .edit(let p) = mode {
                                        onDelete?(p)
                                    }
                                    _ = id  // silence unused
                                }
                                Button("בטל", role: .cancel) {}
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isEdit ? "ערוך פרופיל" : "פרופיל חדש")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("בטל") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("שמור") { save() }
                        .disabled(!canSave)
                        .fontWeight(.bold)
                }
            }
            .photosPicker(
                isPresented: $showPicker,
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: pickerItem) { _, newItem in
                Task { await loadPhoto(newItem) }
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
            avatarPresetID: avatarPresetID
        )
        return VStack(spacing: 10) {
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
            Text("שם")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            TextField("איך קוראים לך?", text: $name)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    private var genderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ילד או ילדה?")
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
            Text("בן/בת כמה?")
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

    private var learningLevelRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("רמת למידה התחלתית")
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
            Text("תחומי עניין (לפיד החכם)")
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
            Text("בחר דמות התחלתית")
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
            Text("תמונה אישית (אופציונלי)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 10) {
                Button {
                    showPicker = true
                } label: {
                    Label(photoData == nil ? "בחר תמונה" : "החלף תמונה",
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
                        Label("הסר", systemImage: "trash")
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
            grade = p.grade
            interests = Set(p.interests)
            learningLevel = p.learningLevel
        } else {
            // Sensible defaults for the create flow
            avatarPresetID = AvatarPreset.defaultID(for: nil)
        }
    }

    private func save() {
        guard canSave else { return }
        let p = Profile(
            id: existingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            gender: gender,
            age: age,
            photoData: photoData,
            avatarPresetID: avatarPresetID,
            createdAt: .now,
            grade: grade,
            interests: Array(interests),
            learningLevel: learningLevel
        )
        Haptic.success()
        SoundPlayer.shared.play(.companionCheer)
        onSave(p)
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let resized = image.resizedSquareForAvatar(maxEdge: 512)
        let jpeg = resized.jpegData(compressionQuality: 0.82)
        await MainActor.run {
            photoData = jpeg
            Haptic.success()
        }
    }
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
