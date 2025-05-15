import SwiftUI
import CoreLocation
import CoreMotion

import MapKit
import Combine
import AVFoundation

///Info.plist con permisos de: Camera, Location, Motion


// MARK: - UI
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

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
                AppleMapView(region: $region, locationManager: locationManager)
                .edgesIgnoringSafeArea(.all)
            }
            
            // Elementos comunes
            VStack {
                Text("Gira a la derecha")
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                    .background(Color.black)
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





//MARK: - Brujula
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager = CLLocationManager()
    @Published var heading: Double = 0.0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}





//MARK: - Mapa fijo centrado
struct AppleMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @ObservedObject var locationManager: LocationManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Mostrar ubicación
        mapView.showsUserLocation = true
        
        // Bloquear interacción del usuario
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Asegurar orientación al norte y seguimiento centrado
        mapView.setUserTrackingMode(.follow, animated: true)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let camera = MKMapCamera()
        camera.centerCoordinate = locationManager.userLocation
        camera.heading = 0 // Norte fijo
        camera.pitch = 0
        camera.altitude = 300
        mapView.setCamera(camera, animated: true)
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




//MARK: - obtener la ubicación en tiempo real
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
    }
}




//MARK: - Camara
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







// MARK: - Filtro de Kalman 1D
class KalmanFilter {
    private var estimate = 0.0
    private var errorEstimate = 1.0
    private let processNoise = 0.01 // Ruido del proceso
    private let measurementNoise = 0.1 // Ruido de medición

    func update(measurement: Double) -> Double {
        // Paso 1: Predicción
        errorEstimate += processNoise
        
        // Paso 2: Ganancia de Kalman
        let kalmanGain = errorEstimate / (errorEstimate + measurementNoise)
        
        // Paso 3: Corrección
        estimate += kalmanGain * (measurement - estimate)
        errorEstimate *= (1 - kalmanGain)
        
        return estimate
    }
}

// MARK: - Manager de Sensores
class MotionAndLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var motionManager = CMMotionManager()
    
    @Published var gpsSpeed: Double = 0.0
    @Published var imuSpeed: Double = 0.0
    
    private var lastUpdateTime: Date?
    private var velocity: Double = 0.0
    private var kalmanFilter = KalmanFilter()

    override init() {
        super.init()
        setupLocation()
        setupMotion()
    }

    // MARK: - CoreLocation
    private func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        if last.speed >= 0 {
            DispatchQueue.main.async {
                self.gpsSpeed = last.speed // en m/s
            }
        }
    }

    // MARK: - CoreMotion con DeviceMotion
    private func setupMotion() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1 // 10 Hz
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let motion = data else { return }

                // Aceleración corregida (sin gravedad)
                let userAccel = motion.userAcceleration
                let ax = userAccel.x * 9.81
                let ay = userAccel.y * 9.81
                let az = userAccel.z * 9.81
                
                // Magnitud de aceleración neta
                let accMagnitude = sqrt(ax*ax + ay*ay + az*az)
                
                let accThreshold = 0.15 // m/s². Ajusta este valor según sensibilidad deseada
                let currentTime = Date()
                
                if accMagnitude < accThreshold {
                    // Si no hay movimiento significativo, resetea
                    self.velocity = 0.0
                    DispatchQueue.main.async {
                        self.imuSpeed = 0.0
                    }
                    return
                }
                
                // Si sí hay movimiento
                if let lastTime = self.lastUpdateTime {
                    let deltaTime = currentTime.timeIntervalSince(lastTime)
                    self.velocity += accMagnitude * deltaTime
                    
                    // Filtro Kalman
                    let filteredVelocity = self.kalmanFilter.update(measurement: self.velocity)
                    
                    DispatchQueue.main.async {
                        self.imuSpeed = max(0.0, filteredVelocity)
                    }
                }
                self.lastUpdateTime = currentTime
            }
        }
    }
}

