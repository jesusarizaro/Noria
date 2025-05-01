import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var locationManager = LocationManager()
    @Binding var shouldPlaceAnchors: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.environmentTexturing = .automatic
        config.planeDetection = []
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        context.coordinator.arView = arView
        context.coordinator.locationManager = locationManager

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if shouldPlaceAnchors {
            context.coordinator.placeOnlyOrigin()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator {
        var arView: ARView?
        var locationManager: LocationManager?

        func placeOnlyOrigin() {
            guard let arView = arView,
                  let _ = locationManager?.currentLocation else {
                print("⏳ GPS no disponible")
                return
            }

            // Punto del usuario (esfera roja en 0,0,0)
            let originAnchor = AnchorEntity(world: SIMD3<Float>(x: 0, y: 0, z: 0))
            let material = SimpleMaterial(color: .red, roughness: 1.0, isMetallic: false)
            let originSphere = ModelEntity(mesh: .generateSphere(radius: 0.12),
                                           materials: [material])

            originAnchor.addChild(originSphere)
            arView.scene.anchors.append(originAnchor)

            print("✅ Esfera colocada en tu ubicación")
        }
    }
}

