import SwiftUI
import AVFoundation
import Vision

// MARK: - Custom Camera Scanner

struct CustomCameraView: View {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var capturedPages: [UIImage] = []
    @State private var showReview = false
    @State private var detectedRect: VNRectangleObservation?
    @State private var flashOn = false

    var body: some View {
        ZStack {
            if showReview {
                PageReviewView(
                    pages: $capturedPages,
                    onDone: {
                        onComplete(capturedPages)
                    },
                    onAddMore: {
                        showReview = false
                    },
                    onCancel: onCancel
                )
            } else {
                CameraPreviewContainer(
                    detectedRect: $detectedRect,
                    flashOn: $flashOn,
                    onCapture: { image in
                        capturedPages.append(image)
                        showReview = true
                    },
                    onCancel: {
                        if capturedPages.isEmpty {
                            onCancel()
                        } else {
                            showReview = true
                        }
                    },
                    pageCount: capturedPages.count
                )
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Camera Preview Container (SwiftUI wrapper)

struct CameraPreviewContainer: View {
    @Binding var detectedRect: VNRectangleObservation?
    @Binding var flashOn: Bool
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let pageCount: Int

    @State private var captureHaptic: Int = 0

    var body: some View {
        ZStack {
            CameraRepresentable(
                detectedRect: $detectedRect,
                flashOn: $flashOn,
                onCapture: { image in
                    captureHaptic += 1
                    onCapture(image)
                }
            )
            .ignoresSafeArea()

            // Edge detection overlay
            GeometryReader { geo in
                if let rect = detectedRect {
                    DocumentOutlineShape(observation: rect, viewSize: geo.size)
                        .stroke(Theme.electricBlue, lineWidth: 3)
                        .fill(Theme.electricBlue.opacity(0.08))
                        .animation(.easeInOut(duration: 0.15), value: rect.boundingBox)
                }
            }
            .ignoresSafeArea()

            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: .circle)
                    }

                    Spacer()

                    Button { flashOn.toggle() } label: {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(flashOn ? .yellow : .white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: .circle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Hint text
                Text(detectedRect != nil ? "Document detected — tap to capture" : "Position document in frame")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: .capsule)
                    .animation(.easeInOut, value: detectedRect != nil)

                Spacer().frame(height: 24)

                // Bottom bar
                HStack(alignment: .center, spacing: 40) {
                    // Page count badge
                    if pageCount > 0 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Text("\(pageCount)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    } else {
                        Spacer().frame(width: 48)
                    }

                    // Capture button
                    Button {
                        NotificationCenter.default.post(name: .capturePhoto, object: nil)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        }
                    }

                    Spacer().frame(width: 48)
                }
                .padding(.bottom, 40)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: captureHaptic)
    }
}

// MARK: - Document Outline Shape

struct DocumentOutlineShape: Shape {
    let observation: VNRectangleObservation
    let viewSize: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Vision coordinates: origin bottom-left, normalized 0-1
        // Convert to view coordinates: origin top-left
        let tl = CGPoint(x: observation.topLeft.x * viewSize.width, y: (1 - observation.topLeft.y) * viewSize.height)
        let tr = CGPoint(x: observation.topRight.x * viewSize.width, y: (1 - observation.topRight.y) * viewSize.height)
        let br = CGPoint(x: observation.bottomRight.x * viewSize.width, y: (1 - observation.bottomRight.y) * viewSize.height)
        let bl = CGPoint(x: observation.bottomLeft.x * viewSize.width, y: (1 - observation.bottomLeft.y) * viewSize.height)

        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()
        return path
    }
}

// MARK: - Camera UIKit Representable

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

struct CameraRepresentable: UIViewControllerRepresentable {
    @Binding var detectedRect: VNRectangleObservation?
    @Binding var flashOn: Bool
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onRectDetected = { rect in
            Task { @MainActor in
                self.detectedRect = rect
            }
        }
        vc.onPhotoCaptured = { image in
            Task { @MainActor in
                self.onCapture(image)
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.updateFlash(flashOn)
    }
}

// MARK: - Camera View Controller (AVFoundation)

class CameraViewController: UIViewController {
    var onRectDetected: ((VNRectangleObservation?) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.pdfx.camera.processing")
    private var lastDetectedRect: VNRectangleObservation?
    private var captureObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        captureObserver = NotificationCenter.default.addObserver(
            forName: .capturePhoto,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.capturePhoto()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        if let observer = captureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        session.stopRunning()
    }

    func updateFlash(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    private func setupCamera() {
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        // Enable auto-focus continuous
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            camera.unlockForConfiguration()
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        // Video output for rectangle detection
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off // Flash handled via torch
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Rectangle Detection

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let rect = results.first else {
                self?.onRectDetected?(nil)
                return
            }
            self?.lastDetectedRect = rect
            self?.onRectDetected?(rect)
        }
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.3
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
    }
}

// MARK: - Photo Capture + Perspective Correction

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // Apply perspective correction if rectangle was detected
        if let rect = lastDetectedRect, let corrected = perspectiveCorrect(image: image, rect: rect) {
            onPhotoCaptured?(corrected)
        } else {
            onPhotoCaptured?(image)
        }
    }

    private nonisolated func perspectiveCorrect(image: UIImage, rect: VNRectangleObservation) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let imageSize = ciImage.extent.size
        let topLeft = CGPoint(x: rect.topLeft.x * imageSize.width, y: rect.topLeft.y * imageSize.height)
        let topRight = CGPoint(x: rect.topRight.x * imageSize.width, y: rect.topRight.y * imageSize.height)
        let bottomLeft = CGPoint(x: rect.bottomLeft.x * imageSize.width, y: rect.bottomLeft.y * imageSize.height)
        let bottomRight = CGPoint(x: rect.bottomRight.x * imageSize.width, y: rect.bottomRight.y * imageSize.height)

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])

        let context = CIContext()
        guard let cgImage = context.createCGImage(corrected, from: corrected.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Page Review View

struct PageReviewView: View {
    @Binding var pages: [UIImage]
    let onDone: () -> Void
    let onAddMore: () -> Void
    let onCancel: () -> Void

    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(pages.count) page\(pages.count == 1 ? "" : "s") scanned")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Button("Done") { onDone() }
                        .font(.headline)
                        .foregroundStyle(Theme.electricBlue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Page preview
                TabView(selection: $currentIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        Image(uiImage: pages[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))

                // Bottom controls
                HStack(spacing: 32) {
                    // Retake current page
                    Button {
                        pages.remove(at: currentIndex)
                        if pages.isEmpty {
                            onAddMore() // Go back to camera
                        } else {
                            currentIndex = min(currentIndex, pages.count - 1)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 22))
                            Text("Retake")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }

                    // Add more pages
                    Button { onAddMore() } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Theme.electricBlue)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Add Page")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    // Delete current page
                    Button {
                        pages.remove(at: currentIndex)
                        if pages.isEmpty {
                            onCancel()
                        } else {
                            currentIndex = min(currentIndex, pages.count - 1)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 22))
                            Text("Delete")
                                .font(.caption)
                        }
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(.vertical, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            currentIndex = pages.count - 1
        }
    }
}
