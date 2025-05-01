import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var locationManager = LocationManager()

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if let userLocation = locationManager.currentLocation {
                let realWorldCoordinates = [
                    CLLocationCoordinate2D(latitude: 5.6981, longitude: -73.5251),
                    CLLocationCoordinate2D(latitude: 5.6982, longitude: -73.5252),
                    CLLocationCoordinate2D(latitude: 5.6983, longitude: -73.5253)
                ]

                let origin = CLLocation(latitude: realWorldCoordinates[0].latitude, longitude: realWorldCoordinates[0].longitude)

                for coord in realWorldCoordinates {
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let translation = translate(from: origin, to: loc)
                    let anchor = AnchorEntity(world: SIMD3(x: Float(translation.x), y: 0, z: Float(translation.y)))
                    let sphere = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [SimpleMaterial(color: .blue, isMetallic: false)])
                    anchor.addChild(sphere)
                    arView.scene.anchors.append(anchor)
                }
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func translate(from origin: CLLocation, to location: CLLocation) -> (x: Double, y: Double) {
        let distance = location.distance(from: origin)

        let bearing = bearingBetween(start: origin.coordinate, end: location.coordinate)
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

extension Double {
    func toRadians() -> Double { return self * .pi / 180 }
}
