import SwiftUI
import PhotosUI

/// Circular avatar of the child. Shows either:
///   • the picked photo (cropped to a circle), or
///   • a gender-based emoji fallback (👦 / 👧 / 🧒).
///
/// Tapping opens a PhotosPicker; selecting a photo persists a compressed
/// version on ParentSettings. Long-press resets to the emoji fallback.
struct ChildAvatarView: View {
    @EnvironmentObject var settings: ParentSettings

    var size: CGFloat = 48
    var allowEditing: Bool = true
    var onTap: (() -> Void)? = nil   // override default behavior (opens picker)

    @State private var pickerItem: PhotosPickerItem?
    @State private var isPickerVisible = false
    @State private var animatePop = false

    private var fallbackEmoji: String {
        switch settings.childGender {
        case .boy: return "👦"
        case .girl: return "👧"
        case .none: return "🧒"
        }
    }

    /// Decoded image (recomputed when the underlying data changes).
    private var uiImage: UIImage? {
        guard let data = settings.childPhotoData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else if allowEditing {
                Button {
                    Haptic.light()
                    isPickerVisible = true
                } label: { content }
                .buttonStyle(.plain)
                .photosPicker(
                    isPresented: $isPickerVisible,
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                )
                .onChange(of: pickerItem) { _, newItem in
                    Task { await loadAndStore(newItem) }
                }
                .contextMenu {
                    if settings.childPhotoData != nil {
                        Button(role: .destructive) {
                            settings.childPhotoData = nil
                        } label: {
                            Label("הסר תמונה", systemImage: "trash")
                        }
                    }
                    Button {
                        isPickerVisible = true
                    } label: {
                        Label("בחר תמונה חדשה", systemImage: "photo")
                    }
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            // Glow / ring
            Circle()
                .fill(.white.opacity(0.18))
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [AppColor.starGold, AppColor.companionGlow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                )

            // Photo (or emoji fallback)
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(Circle())
            } else {
                Text(fallbackEmoji)
                    .font(.system(size: size * 0.55))
            }

            // Pencil affordance — only when editable & not handed off via onTap
            if allowEditing && onTap == nil {
                Circle()
                    .fill(AppColor.starGold)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: size * 0.16, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: size * 0.30, y: size * 0.30)
                    // In RTL the badge naturally lands on the bottom-leading
                    // (visually = bottom-right). That's the standard avatar
                    // edit-badge position, so we leave it alone.
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(animatePop ? 1.10 : 1.0)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }

    private func loadAndStore(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        // Resize so we don't bloat UserDefaults. 512px is plenty for a tiny avatar.
        let resized = image.resizedSquare(maxEdge: 512)
        let jpeg = resized.jpegData(compressionQuality: 0.82)

        await MainActor.run {
            settings.childPhotoData = jpeg
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                animatePop = true
            }
            Haptic.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animatePop = false
                }
            }
        }
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    /// Crops to a centered square then resizes the longest edge to `maxEdge`.
    func resizedSquare(maxEdge: CGFloat) -> UIImage {
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

#Preview {
    HStack(spacing: 30) {
        ChildAvatarView(size: 64)
        ChildAvatarView(size: 84)
    }
    .padding()
    .background(AppGradient.dreamy)
    .environmentObject(ParentSettings.shared)
}
