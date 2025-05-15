import SwiftUI
import AVFoundation
import Vision
import CoreML

struct ContentView: View {
    var body: some View {
        YOLOCameraView()
            .edgesIgnoringSafeArea(.all)
    }
}







struct YOLOCameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> YOLOCameraViewController {
        return YOLOCameraViewController()
    }

    func updateUIViewController(_ uiViewController: YOLOCameraViewController, context: Context) {}
}

class YOLOCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var yoloModel: VNCoreMLModel?
    
    ///dibuja los boxes para los objetos detectados
    var detectionOverlay: CALayer! = nil
    
    ///dice lo que ve gracias a YOLO
    let speechSynthesizer = AVSpeechSynthesizer()
    var ultimoObjetoDetectado: String? = nil
    
    ///dice SOLAMENTE estas etiquetas
    let etiquetasPermitidas: Set<String> = ["person", "car", "chair", "cat", "dog"]

    ///traduce del inglés al español las etiquetas
    let traducciones: [String: String] = [
        "person": "persona",
        "car": "carro",
        "chair": "silla",
        "cat": "gato",
        "dog": "perro"
    ]
    
    ///indica el género de la palabra en español
    let generos: [String: String] = [
        "persona": "f", // femenino
        "carro": "m",   // masculino
        "silla": "f",
        "gato": "m",
        "perro": "m"
    ]





    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupModel()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              captureSession.canAddInput(input)
        else {
            print("⚠️ No se pudo acceder a la cámara")
            return
        }

        captureSession.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        detectionOverlay = CALayer()
        detectionOverlay.frame = view.bounds
        detectionOverlay.sublayers = []
        view.layer.addSublayer(detectionOverlay)

        captureSession.startRunning()
    }

    func setupModel() {
        do {
            let model = try YOLOv3(configuration: MLModelConfiguration()) // Asegúrate que se llame así
            yoloModel = try VNCoreMLModel(for: model.model)
        } catch {
            print("❌ Error al cargar el modelo YOLOv3: \(error)")
            yoloModel = nil
        }
    }

    
    func drawBoundingBox(_ observation: VNRecognizedObjectObservation, etiqueta: String) -> String {
        let boundingBox = observation.boundingBox
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height

        let rect = CGRect(
            x: boundingBox.origin.x * viewWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * viewHeight,
            width: boundingBox.width * viewWidth,
            height: boundingBox.height * viewHeight
        )

        // Capa del recuadro
        let boxLayer = CALayer()
        boxLayer.frame = rect
        boxLayer.borderWidth = 2.0
        boxLayer.borderColor = UIColor.red.cgColor
        boxLayer.cornerRadius = 4
        detectionOverlay.addSublayer(boxLayer)

        // Capa del texto
        let textLayer = CATextLayer()
        textLayer.string = etiqueta
        textLayer.fontSize = 14
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: rect.origin.x, y: rect.origin.y - 20, width: rect.width, height: 20)
        textLayer.cornerRadius = 4
        textLayer.masksToBounds = true
        detectionOverlay.addSublayer(textLayer)

        return etiqueta
    }


    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let yoloModel = yoloModel else {
            print("❌ El modelo no está disponible.")
            return
        }

        let request = VNCoreMLRequest(model: yoloModel) { (request, error) in
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }

            DispatchQueue.main.async {
                // 1. Borrar cuadros anteriores
                self.detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }

                var etiquetasVisibles: [String] = []

                // 2. Dibujar cajas y recolectar etiquetas visibles
                for resultado in results {
                    guard let etiquetaIngles = resultado.labels.first?.identifier else { continue }

                    if self.etiquetasPermitidas.contains(etiquetaIngles) {
                        let nombreTraducido = self.traducciones[etiquetaIngles] ?? etiquetaIngles
                        let etiquetaMostrada = self.drawBoundingBox(resultado, etiqueta: nombreTraducido)
                        etiquetasVisibles.append(etiquetaMostrada)
                    }
                }

                // 3. Hablar solo si hay una etiqueta visible (ya graficada)
                if let etiquetaDetectada = etiquetasVisibles.first,
                   self.ultimoObjetoDetectado != etiquetaDetectada {

                    self.ultimoObjetoDetectado = etiquetaDetectada
                    let genero = self.generos[etiquetaDetectada] ?? "m"
                    let articulo = genero == "f" ? "una" : "un"
                    let mensaje = "Tienes \(articulo) \(etiquetaDetectada) al frente"

                    let utterance = AVSpeechUtterance(string: mensaje)
                    utterance.voice = AVSpeechSynthesisVoice(language: "es-US")
                    utterance.rate = 0.5
                    self.speechSynthesizer.speak(utterance)
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])
    }
}
