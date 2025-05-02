import SwiftUI
import RealityKit
import ARKit
import CoreLocation

// Esta estructura muestra el espacio de realidad aumentada con la cámara.
// También recibe una señal (shouldPlaceAnchors) para saber si debe colocar la esfera.
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var locationManager = LocationManager()
    @Binding var shouldPlaceAnchors: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
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

    // Esta clase se encarga de colocar las anclas (esferas) en el mundo AR
    class Coordinator {
        var arView: ARView?
        var locationManager: LocationManager?
        var hasPlacedAnchors = false // ✅ Bandera para colocar solo una vez

        func placeOnlyOrigin() {
            // Si ya colocamos las anclas, no lo hacemos de nuevo
            guard !hasPlacedAnchors else { return }
            hasPlacedAnchors = true

            guard let arView = arView,
                  let originLocation = locationManager?.currentLocation else {
                print("⏳ GPS no disponible")
                return
            }

            // Limpiar escena para evitar duplicados si la app reinicia
            arView.scene.anchors.removeAll()

            // Coordenada adicional (latitud, longitud) que tú puedes modificar
            let extraCoordinate = CLLocationCoordinate2D(latitude: 10.987566597755182, longitude: -74.81916364159487)
            let pointLocation = CLLocation(latitude: extraCoordinate.latitude, longitude: extraCoordinate.longitude)

            // Colocamos la esfera azul en su posición REAL con respecto al mundo
            let geoAnchor = AnchorEntity(world: .zero)
            let offset = translate(from: originLocation, to: pointLocation)
            let blueSphere = ModelEntity(mesh: .generateSphere(radius: 0.1),
                                         materials: [SimpleMaterial(color: .blue, roughness: 1.0, isMetallic: false)])
            blueSphere.position = SIMD3(x: Float(offset.x), y: 0, z: Float(offset.z))
            geoAnchor.addChild(blueSphere)
            arView.scene.anchors.append(geoAnchor)

            // Ahora colocamos la esfera roja en el ORIGEN (del usuario)
            let userAnchor = AnchorEntity(world: SIMD3<Float>(x: 0, y: 0, z: 0))
            let redSphere = ModelEntity(mesh: .generateSphere(radius: 0.12),
                                        materials: [SimpleMaterial(color: .red, roughness: 1.0, isMetallic: false)])
            userAnchor.addChild(redSphere)
            arView.scene.anchors.append(userAnchor)

            print("✅ Esferas colocadas: azul en coordenada real, roja en tu posición")
        }

        func translate(from origin: CLLocation, to destination: CLLocation) -> (x: Double, z: Double) {
            let distance = destination.distance(from: origin)
            let bearing = bearingBetween(start: origin.coordinate, end: destination.coordinate)
            let x = distance * sin(bearing)
            let z = distance * cos(bearing)
            return (x, z)
        }

        func bearingBetween(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> Double {
            let lat1 = start.latitude.toRadians()
            let lon1 = start.longitude.toRadians()
            let lat2 = end.latitude.toRadians()
            let lon2 = end.longitude.toRadians()

            let dLon = lon2 - lon1
            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            return atan2(y, x)
        }
    }
}

extension Double {
    func toRadians() -> Double { return self * .pi / 180 }
}
