import SwiftUI
import MapKit
import RealityKit
import ARKit

struct ContentView: View {
    @State private var showMap = true
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 11.0195, longitude: -74.8504),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    )

    var body: some View {
        ZStack {
            // Fondo: siempre la cámara AR
            ARViewContainer()

            // Si showMap es true, se sobrepone la interfaz del mapa con fondo negro
            if showMap {
                VStack(spacing: 20) {
                    Spacer()

                    // Mapa en el centro
                    Map(coordinateRegion: $region)
                        .frame(width: 400, height: 500)
                        .cornerRadius(10)

                    // Botones
                    HStack(spacing: 20) {
                        Button("📷 Cámara") {
                            showMap = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("📍 Quiero ir a...") {
                            // Por ahora no hace nada
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black) // Fondo negro para ocultar la cámara
                .edgesIgnoringSafeArea(.all)
            } else {
                // Botón para volver al mapa
                VStack {
                    Spacer()
                    Button("🗺️ Mapa") {
                        showMap = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(0)

                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Cámara AR como fondo fijo
struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
