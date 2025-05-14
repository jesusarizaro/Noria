import SwiftUI
import MapKit
import CoreLocation
import Combine
import AVFoundation

struct ContentView: View {
    @State private var showMap = true
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    
    
    var body: some View {
        ZStack {
            // Fondo: cámara sin AR
            CameraView()
                .edgesIgnoringSafeArea(.all)
            
            if showMap {
                AppleMapView(region: $region)
                    .edgesIgnoringSafeArea(.all)

                
                .edgesIgnoringSafeArea(.all)
            }
            
            // Elementos comunes
            VStack {
                Text("Gira a la derecha")
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(40)
                    .font(.title3)
                    .padding(.top, 90)
                
                Spacer()
                
                HStack(spacing: 40) {
                    Button(action: {
                        showMap.toggle()
                    }) {
                        Text(showMap ? "📷" : "🗺️")
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(Color.yellow)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 6))
                    }
                    
                    Button(action: {
                        // Acción de voz aquí
                    }) {
                        Text("🎤")
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(Color.yellow)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 6))
                    }
                }
                .padding(.bottom, 100)
            }
            .edgesIgnoringSafeArea(.all)



            }
        }
    }













struct CameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return view
        }

        session.addInput(input)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        ///Iniciar en segundo plano para evitar congelamiento de UI
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}





struct AppleMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator


        // ✅ Mostrar ubicación del usuario
        mapView.showsUserLocation = true
        mapView.showsCompass = false

        // ✅ Habilitar gestos de rotación
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true

        // ✅ Centro inicial
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(region: $region)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var region: MKCoordinateRegion

        init(region: Binding<MKCoordinateRegion>) {
            _region = region
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            region = mapView.region
        }
    }
}
