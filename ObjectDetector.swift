import Vision
import CoreML

class ObjectDetector {
    static let shared = ObjectDetector()
    
    private var model: VNCoreMLModel?
    var detectedObjects: [String] = [] // 📌 Lista para guardar los objetos detectados

    private init() {
        guard let mlModel = try? YOLOv3(configuration: .init()).model,
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            print("Error al cargar el modelo ML")
            return
        }
        self.model = visionModel
    }
    
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNRecognizedObjectObservation] {
        guard let model = self.model else { return [] }
        
        let request = VNCoreMLRequest(model: model)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            let results = request.results as? [VNRecognizedObjectObservation] ?? []
            
            // 📌 Guardar objetos detectados en la lista
            for result in results {
                if let label = result.labels.first?.identifier {
                    if !detectedObjects.contains(label) { // Evita duplicados
                        detectedObjects.append(label)
                    }
                }
            }
            
            return results
        } catch {
            print("Error al procesar la imagen: \(error)")
            return []
        }
    }
}
