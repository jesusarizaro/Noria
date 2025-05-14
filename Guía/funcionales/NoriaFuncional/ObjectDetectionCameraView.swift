import SwiftUI
import AVFoundation
import Vision

struct ObjectDetectionCameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer!
        private var detectionOverlay: CALayer!
        private var requests = [VNRequest]()

        override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
            setupModel()
        }

        private func setupCamera() {
            captureSession.sessionPreset = .high
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }
            captureSession.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            captureSession.addOutput(output)

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            detectionOverlay = CALayer()
            detectionOverlay.frame = view.bounds
            view.layer.addSublayer(detectionOverlay)

            captureSession.startRunning()
        }

        private func setupModel() {
            guard let model = try? VNCoreMLModel(for: YOLOv3().model) else { return }

            let request = VNCoreMLRequest(model: model) { [weak self] request, _ in
                DispatchQueue.main.async {
                    self?.handleDetections(request: request)
                }
            }

            request.imageCropAndScaleOption = .scaleFill
            self.requests = [request]
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform(self.requests)
        }

        private func handleDetections(request: VNRequest) {
            detectionOverlay.sublayers = nil

            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }

            for observation in results {
                let box = VNImageRectForNormalizedRect(observation.boundingBox,
                                                       Int(view.bounds.width),
                                                       Int(view.bounds.height))

                let outline = CALayer()
                outline.frame = box
                outline.borderColor = UIColor.red.cgColor
                outline.borderWidth = 2
                detectionOverlay.addSublayer(outline)

                if let label = observation.labels.first {
                    let textLayer = CATextLayer()
                    textLayer.string = "\(label.identifier) (\(Int(label.confidence * 100))%)"
                    textLayer.fontSize = 14
                    textLayer.foregroundColor = UIColor.white.cgColor
                    textLayer.backgroundColor = UIColor.red.cgColor
                    textLayer.frame = CGRect(x: box.origin.x, y: box.origin.y - 20, width: 150, height: 20)
                    detectionOverlay.addSublayer(textLayer)
                }
            }
        }
    }
}
