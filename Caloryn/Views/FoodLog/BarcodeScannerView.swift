import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void

        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }

        func didScanBarcode(_ code: String) {
            onBarcodeScanned(code)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var hasScanned = false

    private let supportedTypes: [AVMetadataObject.ObjectType] = [
        .ean8, .ean13, .upce,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDeniedOverlay()
                    }
                }
            }
            return
        case .denied, .restricted:
            showPermissionDeniedOverlay()
            return
        @unknown default:
            showPermissionDeniedOverlay()
            return
        }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showPermissionDeniedOverlay()
            return
        }

        captureSession.sessionPreset = .high

        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        configureCameraDevice(device)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = supportedTypes

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        addScanOverlay()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.restrictScanArea(metadataOutput)
            }
        }
    }

    private func configureCameraDevice(_ device: AVCaptureDevice) {
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.maxAvailableVideoZoomFactor >= 1.5 {
            device.videoZoomFactor = 1.5
        }
        device.unlockForConfiguration()
    }

    /// Restricts metadata detection to the visible cutout area.
    /// Must be called after the session is running so `metadataOutputRectConverted` works.
    private func restrictScanArea(_ output: AVCaptureMetadataOutput) {
        guard let previewLayer else { return }
        let bounds = view.bounds
        let cutoutSize = CGSize(width: 280, height: 160)
        let cutoutRect = CGRect(
            x: (bounds.width - cutoutSize.width) / 2,
            y: (bounds.height - cutoutSize.height) / 2 - 40,
            width: cutoutSize.width,
            height: cutoutSize.height
        )
        output.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: cutoutRect)
    }

    private func addScanOverlay() {
        let overlay = ScannerOverlayView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)

        let title = UILabel()
        title.text = "Center the barcode in the frame"
        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .white
        title.textAlignment = .center
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true

        let guidance = UILabel()
        guidance.text = "Hold steady. If it doesn’t scan, adjust the distance or lighting."
        guidance.font = .preferredFont(forTextStyle: .subheadline)
        guidance.textColor = UIColor.white.withAlphaComponent(0.86)
        guidance.textAlignment = .center
        guidance.numberOfLines = 0
        guidance.adjustsFontForContentSizeCategory = true

        let instructions = UIStackView(arrangedSubviews: [title, guidance])
        instructions.axis = .vertical
        instructions.spacing = 6
        instructions.alignment = .fill
        instructions.translatesAutoresizingMaskIntoConstraints = false
        instructions.isAccessibilityElement = true
        instructions.accessibilityLabel = "\(title.text ?? ""). \(guidance.text ?? "")"
        view.addSubview(instructions)

        NSLayoutConstraint.activate([
            instructions.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 70),
            instructions.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            instructions.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
        ])
    }

    private func showPermissionDeniedOverlay() {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 20
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Camera access is required\nto scan barcodes."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Open Settings"
        buttonConfiguration.baseBackgroundColor = .white
        buttonConfiguration.baseForegroundColor = .black
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        buttonConfiguration.cornerStyle = .fixed
        buttonConfiguration.background.cornerRadius = 12
        buttonConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .headline)
            return attributes
        }

        let button = UIButton(configuration: buttonConfiguration)
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        container.addArrangedSubview(label)
        container.addArrangedSubview(button)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
        ])
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue,
              let normalizedBarcode = BarcodeIdentity.normalized(code) else {
            // Metadata that cannot form a supported product identity is not a
            // completed scan. Keep the live camera running so the persistent
            // guidance remains immediately actionable.
            return
        }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        captureSession.stopRunning()
        delegate?.didScanBarcode(normalizedBarcode)
    }
}

// MARK: - Scan Region Overlay

private final class ScannerOverlayView: UIView {
    private let cutoutSize = CGSize(width: 280, height: 160)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cutout = CGRect(
            x: (rect.width - cutoutSize.width) / 2,
            y: (rect.height - cutoutSize.height) / 2 - 40,
            width: cutoutSize.width,
            height: cutoutSize.height
        )

        ctx.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        ctx.fill(rect)

        let roundedPath = UIBezierPath(roundedRect: cutout, cornerRadius: 16)
        ctx.setBlendMode(.clear)
        roundedPath.fill()

        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2)
        roundedPath.stroke()

        drawCornerBrackets(in: ctx, rect: cutout)
    }

    private func drawCornerBrackets(in ctx: CGContext, rect: CGRect) {
        let length: CGFloat = 24
        let radius: CGFloat = 8

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)

        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 0, .pi / 2),
            (CGPoint(x: rect.maxX, y: rect.minY), -.pi / 2, 0),
            (CGPoint(x: rect.minX, y: rect.maxY), .pi / 2, .pi),
            (CGPoint(x: rect.maxX, y: rect.maxY), .pi, 3 * .pi / 2),
        ]

        for (corner, _, _) in corners {
            let isLeft = corner.x == rect.minX
            let isTop = corner.y == rect.minY
            let xDir: CGFloat = isLeft ? 1 : -1
            let yDir: CGFloat = isTop ? 1 : -1

            let path = UIBezierPath()
            path.move(to: CGPoint(x: corner.x + xDir * length, y: corner.y))
            path.addLine(to: CGPoint(x: corner.x + xDir * radius, y: corner.y))
            path.addQuadCurve(
                to: CGPoint(x: corner.x, y: corner.y + yDir * radius),
                controlPoint: corner
            )
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + yDir * length))
            ctx.addPath(path.cgPath)
            ctx.strokePath()
        }
    }
}
