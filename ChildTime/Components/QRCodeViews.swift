import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

/// Renders a scannable QR code for a string (e.g. a family invite code).
struct QRCodeView: View {
    let text: String
    var size: CGFloat = 200

    var body: some View {
        Group {
            if let img = Self.image(for: text) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    static func image(for text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Live camera QR scanner. Calls `onScan` once with the decoded string.
struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let vc = ScannerController()
        vc.onScan = onScan
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var didScan = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            // Handle camera permission explicitly so a denied/undetermined state
            // doesn't just show a silent black screen that "reads nothing".
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.setupSession() }
                        else { self?.showMessage("אֵין הַרְשָׁאָה לְמַצְלֵמָה.\nהַקְלִידוּ אֶת הַקּוֹד בִּמְקוֹם זֹאת.") }
                    }
                }
            default:
                showMessage("אֵין הַרְשָׁאָה לְמַצְלֵמָה.\nהַקְלִידוּ אֶת הַקּוֹד בִּמְקוֹם זֹאת.")
            }
        }

        private func setupSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                // No camera (e.g. the Simulator) — point to the code field.
                showMessage("אֵין מַצְלֵמָה בַּמַּכְשִׁיר הַזֶּה.\nהַקְלִידוּ אֶת הַקּוֹד בִּמְקוֹם זֹאת.")
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.layer.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview
            applyRotation()
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }

        private func showMessage(_ text: String) {
            let label = UILabel()
            label.text = text
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 17, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
            applyRotation()
        }

        override func viewWillTransition(to size: CGSize,
                                         with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: { _ in
                self.previewLayer?.frame = self.view.layer.bounds
                self.applyRotation()
            })
        }

        /// Rotate the camera preview to match the current interface orientation —
        /// otherwise the feed is sideways/stretched in landscape (iPad).
        private func applyRotation() {
            guard let connection = previewLayer?.connection else { return }
            let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
            let angle: CGFloat
            switch orientation {
            case .portrait:           angle = 90
            case .portraitUpsideDown: angle = 270
            case .landscapeLeft:      angle = 180
            case .landscapeRight:     angle = 0
            default:                  angle = 90
            }
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            didScan = false
            // Only resume once the session actually has the camera input wired up
            // (setupSession owns the first start).
            if !session.isRunning && !session.inputs.isEmpty {
                DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
            }
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didScan,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue, !value.isEmpty else { return }
            didScan = true
            Haptic.success()
            onScan?(value)
        }
    }
}
