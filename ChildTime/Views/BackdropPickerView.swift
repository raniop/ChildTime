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
                            photoButtons
                            LazyVGrid(columns: columns, spacing: 12) {
                                if let photo = store.photo(for: owner) {
                                    tile(name: word(tr("הַתְּמוּנָה שֶׁלִּי")), selected: selectedID == BackdropTheme.photoID) {
                                        Image(uiImage: photo).resizable().scaledToFill()
                                    } action: { store.choosePhoto(for: owner) }
                                } else {
                                    emptyPhotoTile
                                }
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

    /// Where their own photo will sit, before there is one.
    private var emptyPhotoTile: some View {
        Text(word(tr("הַתְּמוּנָה שֶׁלִּי תּוֹפִיעַ כָּאן")))
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(0.62, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.24)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
            .accessibilityHidden(true)
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
            // The tile sets the size and the art fills it — a picture laid out
            // by its own proportions would push the tile wider than its column.
            Color.clear
                .aspectRatio(0.62, contentMode: .fit)
                .overlay { art() }
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
                            .foregroundStyle(.white, Color(hex: "2FD67B"))   // strong enough on a busy picture
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
