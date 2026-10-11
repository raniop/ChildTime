import SwiftUI
import PhotosUI

/// 🎨 Choose the backdrop, in three tabs (Rani, 2026-10-11: "צריך להיות מופרד
/// תמונות ורקעים רגילים"): 🖼 the built-in pictures, 🎨 the built-in colours,
/// 📷 a photo of your own (camera or album). For a child (their own, pointed
/// Hebrew) and for the parent. Tapping one applies it at once: this screen
/// sits on the backdrop itself, so the whole page changes under the finger.
struct BackdropPickerView: View {
    let owner: BackdropStore.Owner

    @ObservedObject private var store = BackdropStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var libraryItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var choosingSource = false
    @State private var photoToRemove: String?
    @State private var tab: Tab = Tab.demo ?? .pictures

    private enum Tab: String, CaseIterable {
        case pictures, colours, mine
        var title: String {
            switch self {
            case .pictures: return tr("🖼 תְּמוּנוֹת")
            case .colours:  return tr("🎨 צְבָעִים")
            case .mine:     return tr("📷 מִשֶּׁלִּי")
            }
        }
        /// 🧪 DEMO_BACKDROP_TAB=colours|mine — screenshots.
        static var demo: Tab? {
            #if DEBUG
            return ProcessInfo.processInfo.environment["DEMO_BACKDROP_TAB"].flatMap(Tab.init(rawValue:))
            #else
            return nil
            #endif
        }
    }

    private var forChild: Bool { owner != .parent }
    /// A child reads pointed Hebrew; a parent's screens carry none.
    private func word(_ s: String) -> String { forChild ? s : Question.stripNiqqud(s) }
    private var cancelWord: String { forChild ? tr("בִּטּוּל") : tr("ביטול") }
    private var selectedID: String {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["DEMO_BACKDROP"] { return id }
        #endif
        return store.backdropID(for: owner) ?? BackdropTheme.tofy.id
    }
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

                tabBar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .frame(maxWidth: 720)

                ScrollView {
                    VStack(spacing: 14) {
                        switch tab {
                        case .pictures:
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(BackdropPicture.all) { picture in
                                    tile(name: word(picture.displayName), selected: selectedID == picture.id) {
                                        if let thumb = picture.thumbnail { Image(uiImage: thumb).resizable().scaledToFill() }
                                    } action: { store.choose(picture, for: owner) }
                                }
                            }
                        case .colours:
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(BackdropTheme.all) { theme in
                                    tile(name: word(theme.displayName), selected: selectedID == theme.id) {
                                        GeometryReader { g in BackdropArt(theme: theme, size: g.size, scale: 0.3) }
                                    } action: { store.choose(theme, for: owner) }
                                }
                            }
                        case .mine:
                            // No camera / album buttons on top (Rani, 2026-10-11): the ＋ tile is the way in.
                            let canAdd = store.canAddPhoto(for: owner)
                            if !canAdd {
                                Text(word(tr("אֶפְשָׁר לִשְׁמוֹר עַד 6 תְּמוּנוֹת. כְּדֵי לְהוֹסִיף חֲדָשָׁה, מְסִירִים אַחַת.")))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(store.photos(for: owner)) { photo in
                                    photoTile(photo)
                                }
                                if canAdd { addPhotoTile }
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
                    await MainActor.run { if store.addPhoto(image, for: owner) { Haptic.success() } }
                }
                await MainActor.run { libraryItem = nil }
            }
        }
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            BackdropCamera { image in
                showingCamera = false
                if let image, store.addPhoto(image, for: owner) { Haptic.success() }
            }
            .ignoresSafeArea()
        }
        .alert(word(tr("לְהָסִיר אֶת הַתְּמוּנָה?")), isPresented: Binding(
            get: { photoToRemove != nil }, set: { if !$0 { photoToRemove = nil } })) {
            Button(word(tr("הֲסָרָה")), role: .destructive) {
                if let id = photoToRemove { withAnimation(.easeInOut(duration: 0.25)) { store.removePhoto(id, for: owner) } }
                photoToRemove = nil
            }
            Button(cancelWord, role: .cancel) { photoToRemove = nil }
        }
        #if DEBUG
        .onAppear { store.seedDemoPhotos(for: owner) }
        #endif
        // A child's second device: the photos added on the other one.
        .task(id: tab) { if tab == .mine { await store.syncPhotoSet(for: owner) } }
    }

    /// 🖼 🎨 📷 The three tabs — each one a 16pt rounded button; the open one is white.
    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    Haptic.light()
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                } label: {
                    Text(word(t.title))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(tab == t ? Color(hex: "2A1E5C") : .white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tab == t ? Color.white : Color.black.opacity(0.28)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(tab == t ? 0 : 0.30), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
    }

    /// One of their photos: tap to use it, ✕ to take it away.
    private func photoTile(_ photo: BackdropStore.OwnPhoto) -> some View {
        tile(name: "", label: word(tr("הַתְּמוּנָה שֶׁלִּי")), selected: selectedID == photo.id) {
            Image(uiImage: photo.thumbnail).resizable().scaledToFill()
        } action: { store.choosePhoto(photo.id, for: owner) }
        .overlay(alignment: .topLeading) {
            Button {
                Haptic.light()
                photoToRemove = photo.id
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.black.opacity(0.62)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                    .padding(8)                      // a 44pt target around a small mark
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(word(tr("הֲסָרָה")))
        }
    }

    /// ＋ The empty place next to their photos IS the way to add one (Rani,
    /// 2026-10-11): tap → camera or album; once added, a new empty place opens
    /// beside it, up to six.
    private var addPhotoTile: some View {
        Button {
            Haptic.light()
            if UIImagePickerController.isSourceTypeAvailable(.camera) { choosingSource = true } else { showingLibrary = true }
        } label: {
            Color.clear
                .aspectRatio(0.62, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white))
                        Text(word(tr("הוֹסָפַת תְּמוּנָה")))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                    .padding(6)
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.24)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog(word(tr("הוֹסָפַת תְּמוּנָה")), isPresented: $choosingSource, titleVisibility: .hidden) {
            Button("📷 " + word(tr("לְצַלֵּם"))) { showingCamera = true }
            Button("🖼 " + word(tr("מֵהָאַלְבּוֹם"))) { showingLibrary = true }
            Button(cancelWord, role: .cancel) {}
        }
    }

    /// `name` is the caption on the tile; a photo of their own has none (`label` names it for VoiceOver).
    private func tile<Art: View>(name: String, label: String? = nil, selected: Bool,
                                 @ViewBuilder art: () -> Art, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.25)) { action() }
        } label: {
            // The tile sets the size and the art fills it — a picture laid out
            // by its own proportions would push the tile wider than its column.
            Color.clear
                .aspectRatio(0.62, contentMode: .fit)
                .overlay { art() }
                .clipped()
                .overlay(alignment: .bottom) {
                    if !name.isEmpty {
                    Text(name)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 6).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.28))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(selected ? 1 : 0.30), lineWidth: selected ? 3 : 1))
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white, Color(hex: "2FD67B"))   // strong enough on a busy picture
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? name)
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
                if let photo = look.photo(for: g.size) {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height).clipped()
                    // Deeper than on the other screens: the title and the tabs sit
                    // straight on the picture here, with no glass pane under them.
                    Color.black.opacity(0.50)
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
