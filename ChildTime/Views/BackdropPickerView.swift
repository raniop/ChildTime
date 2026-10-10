import SwiftUI
import PhotosUI

/// 🎨 Choose the backdrop — every built-in one, or a photo of your own (camera
/// or album). For a child (their own, pointed Hebrew) and for the parent.
/// Tapping one applies it at once: this screen sits on the backdrop itself, so
/// the whole page changes under the finger.
struct BackdropPickerView: View {
    let owner: BackdropStore.Owner

    @ObservedObject private var store = BackdropStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var libraryItem: PhotosPickerItem?
    @State private var showingCamera = false

    private var forChild: Bool { owner != .parent }
    /// A child reads pointed Hebrew; a parent's screens carry none.
    private func word(_ s: String) -> String { forChild ? s : Question.stripNiqqud(s) }
    private var selectedID: String { store.backdropID(for: owner) ?? BackdropTheme.tofy.id }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: hsc == .compact ? 3 : 5)
    }

    var body: some View {
        ZStack {
            GlassBackdropPreview(owner: owner)
            VStack(spacing: 0) {
                HStack {
                    CornerDismissButton(label: word(Gendered.g(tr("סְגֹר"), tr("סִגְרִי")))) { dismiss() }
                    Spacer()
                    Text("🎨 " + word(forChild ? tr("הָרֶקַע שֶׁלִּי") : tr("רֶקַע")))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .awayFromBar(.leading)
                .clearOfBar()
                .padding(.horizontal, 12)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 14) {
                        photoButtons
                        LazyVGrid(columns: columns, spacing: 12) {
                            if let photo = store.photo(for: owner) {
                                tile(name: word(tr("הַתְּמוּנָה שֶׁלִּי")), selected: selectedID == BackdropTheme.photoID) {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                } action: { store.choosePhoto(for: owner) }
                            }
                            ForEach(BackdropTheme.all) { theme in
                                tile(name: word(theme.displayName), selected: selectedID == theme.id) {
                                    GeometryReader { g in BackdropArt(theme: theme, size: g.size, scale: 0.3) }
                                } action: { store.choose(theme, for: owner) }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .app)
        .onChangeCompat(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await MainActor.run { store.setPhoto(image, for: owner); Haptic.success() }
                }
                await MainActor.run { libraryItem = nil }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            BackdropCamera { image in
                showingCamera = false
                if let image { store.setPhoto(image, for: owner); Haptic.success() }
            }
            .ignoresSafeArea()
        }
    }

    /// 📷 🖼 A photo of their own — the camera, or the album (the system's own
    /// picker: no access to the library is asked for or given).
    private var photoButtons: some View {
        HStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { Haptic.light(); showingCamera = true } label: {
                    photoLabel("📷", word(tr("לְצַלֵּם")))
                }
                .buttonStyle(.plain)
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                photoLabel("🖼", word(tr("מֵהָאַלְבּוֹם")))
            }
            .buttonStyle(.plain)
        }
    }

    private func photoLabel(_ emoji: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 20))
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .glassPane(radius: 16, strength: 0.20)
    }

    private func tile<Art: View>(name: String, selected: Bool,
                                 @ViewBuilder art: () -> Art, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.25)) { action() }
        } label: {
            art()
                .frame(maxWidth: .infinity)
                .aspectRatio(0.62, contentMode: .fill)
                .clipped()
                .overlay(alignment: .bottom) {
                    Text(name)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 6).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.28))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(selected ? 1 : 0.30), lineWidth: selected ? 3 : 1))
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white, GlassInk.good)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The backdrop of THIS owner — the picker opened for a child from a parent's
/// phone must show that child's backdrop, not the parent's.
private struct GlassBackdropPreview: View {
    let owner: BackdropStore.Owner
    @ObservedObject private var store = BackdropStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    var body: some View {
        let look = store.look(for: owner)
        GeometryReader { g in
            ZStack {
                if let photo = look.photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height).clipped()
                    Color.black.opacity(0.30)
                } else {
                    BackdropArt(theme: look.theme, size: g.size)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The camera, for a backdrop photo (PhotosPicker has none).
private struct BackdropCamera: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil) }
    }
}
