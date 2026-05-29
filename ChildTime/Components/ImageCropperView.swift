import SwiftUI

/// Interactive avatar cropper — pinch to zoom, drag to position, inside a
/// circular window. Returns the cropped square image (the circle is just the
/// guide; the avatar views clip to a circle themselves).
struct ImageCropperView: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 300

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: AppSpacing.lg) {
                Text("הַתְאִימוּ אֶת הַתְּמוּנָה")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                // Live preview with the circular guide.
                transformedImage
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                    .glow(AppColor.starGold, radius: 10)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { v in scale = min(6, max(1, lastScale * v)) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { v in
                                    offset = CGSize(width: lastOffset.width + v.translation.width,
                                                    height: lastOffset.height + v.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )

                Text("צַבְטוּ לְהַגְדָּלָה · גַּרְרוּ לְמִקּוּם")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: AppSpacing.md) {
                    Button {
                        Haptic.light()
                        onCancel()
                    } label: {
                        Text("בַּטֵּל")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    Button {
                        Haptic.success()
                        onDone(render())
                    } label: {
                        Text("שְׁמֹר")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppGradient.gold, in: Capsule())
                            .glow(AppColor.starGold, radius: 8)
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(AppSpacing.lg)
        }
    }

    /// The image transformed by the current zoom/pan, clipped to the square
    /// crop window. Used both for the live preview and the final render.
    private var transformedImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: cropSize, height: cropSize)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: cropSize, height: cropSize)
            .clipped()
    }

    @MainActor private func render() -> UIImage {
        let renderer = ImageRenderer(content: transformedImage)
        renderer.scale = 512.0 / cropSize   // ~512px output
        return renderer.uiImage ?? image
    }
}
