import SwiftUI
import AVFoundation
import Vision

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        let speechSynthesizer = AVSpeechSynthesizer()
        var lastSpokenLabel: String?
        var hasWelcomedUser = false
        
        // 🔠 Diccionario de traducciones
        let objectTranslations: [String: String] = [
            "person": "persona",
            "car": "carro",
            "cat": "gato",
            "dog": "perro",
            "bicycle": "bicicleta",
            "bus": "bus",
            "cell phone": "celular",
            "chair": "silla",
            "tv": "televisor",
            "book": "libro"
            // Agrega más si tu modelo detecta más clases
        ]

        override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
            
            // 📢 Mensaje de bienvenida
            if !hasWelcomedUser {
                hasWelcomedUser = true
                speakWelcomeMessage()
            }
        }

        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession.sessionPreset = .high
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("No se pudo acceder a la cámara")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
                
                let output = AVCaptureVideoDataOutput()
                output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if captureSession.canAddOutput(output) {
                    captureSession.addOutput(output)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.layer.bounds
                view.layer.addSublayer(previewLayer)

                DispatchQueue.global(qos: .background).async {
                    self.captureSession.startRunning()
                }
                
            } catch {
                print("Error al configurar la cámara: \(error)")
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let observations = ObjectDetector.shared.detectObjects(pixelBuffer: pixelBuffer)
                DispatchQueue.main.async {
                    self.drawBoundingBoxes(for: observations)
                    self.announceDetectedObjects(observations)
                }
            }
        }

        func drawBoundingBoxes(for observations: [VNRecognizedObjectObservation]) {
            DispatchQueue.main.async {
                self.view.layer.sublayers?.removeSubrange(1...)
            }
            
            for observation in observations {
                let boundingBox = observation.boundingBox
                let label = observation.labels.first?.identifier ?? "Desconocido"
                let confidence = observation.labels.first?.confidence ?? 0.0
                
                let frame = CGRect(
                    x: boundingBox.origin.x * self.view.frame.width,
                    y: (1 - boundingBox.origin.y - boundingBox.height) * self.view.frame.height,
                    width: boundingBox.width * self.view.frame.width,
                    height: boundingBox.height * self.view.frame.height
                )

                let boxLayer = CALayer()
                boxLayer.frame = frame
                boxLayer.borderColor = UIColor.red.cgColor
                boxLayer.borderWidth = 2.0

                let textLayer = CATextLayer()
                textLayer.string = "\(label) \(Int(confidence * 100))%"
                textLayer.foregroundColor = UIColor.white.cgColor
                textLayer.fontSize = 14
                textLayer.frame = CGRect(x: frame.origin.x, y: frame.origin.y - 20, width: frame.width, height: 20)
                textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                textLayer.alignmentMode = .center

                DispatchQueue.main.async {
                    self.view.layer.addSublayer(boxLayer)
                    self.view.layer.addSublayer(textLayer)
                }
            }
        }

        // 📢 Anuncia los objetos detectados en español
        func announceDetectedObjects(_ observations: [VNRecognizedObjectObservation]) {
            guard let observation = observations.first else { return }
            let originalLabel = observation.labels.first?.identifier ?? "Desconocido"
            let translatedLabel = objectTranslations[originalLabel] ?? originalLabel

            // ❌ Evita interrumpir el mensaje de bienvenida o superponer
            if speechSynthesizer.isSpeaking { return }

            if translatedLabel != lastSpokenLabel {
                let utterance = AVSpeechUtterance(string: "Veo un \(translatedLabel)")
                utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
                utterance.rate = 0.5
                speechSynthesizer.speak(utterance)
                lastSpokenLabel = translatedLabel
            }
        }

        // 🎙️ Mensaje de bienvenida
        func speakWelcomeMessage() {
            let welcome = "Hola, soy Noria, asistente de navegación de la Universidad del Norte, y te ayudaré a llegar a tu destino e identificar qué tienes delante de ti. Para comenzar, dime dónde te encuentras y a dónde quieres ir."
            let utterance = AVSpeechUtterance(string: welcome)
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
        }
    }
}
