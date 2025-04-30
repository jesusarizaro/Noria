import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ARViewContainer: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configurar sesión AR
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravity
        arView.session.run(config, options: [])

        // Iniciar ubicación
        context.coordinator.arView = arView
        context.coordinator.routeCoordinates = routeCoordinates
        context.coordinator.locationManager.requestWhenInUseAuthorization()
        context.coordinator.locationManager.startUpdatingLocation()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, CLLocationManagerDelegate {
        var locationManager = CLLocationManager()
        var arView: ARView?
        var routeCoordinates: [CLLocationCoordinate2D] = []

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let currentLocation = locations.last,
                  let arView = arView else { return }

            // Limpiar esferas previas
            arView.scene.anchors.removeAll()

            for coord in routeCoordinates {
                let relativePosition = convertGPSCoordinate(from: currentLocation.coordinate, to: coord)
                let anchor = AnchorEntity(world: relativePosition)
                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.05),
                    materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
                )
                anchor.addChild(sphere)
                arView.scene.anchors.append(anchor)
            }

            locationManager.stopUpdatingLocation() // Solo una vez
        }

        /// Calcula la posición 3D relativa entre dos coordenadas GPS
        func convertGPSCoordinate(from origin: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) -> SIMD3<Float> {
            let earthRadius: Double = 6378137 // en metros

            let dLat = (target.latitude - origin.latitude) * .pi / 180
            let dLon = (target.longitude - origin.longitude) * .pi / 180

            let lat1 = origin.latitude * .pi / 180
            let lat2 = target.latitude * .pi / 180

            let x = earthRadius * dLon * cos((lat1 + lat2) / 2)
            let z = earthRadius * dLat

            // Retornar como posición relativa en espacio AR
            return SIMD3<Float>(Float(x), 0, -Float(z))
        }
    }
}
