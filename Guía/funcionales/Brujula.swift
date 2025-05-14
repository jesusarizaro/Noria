import SwiftUI
import UIKit
import CoreLocation
import Combine


struct ContentView: View {
    @StateObject private var compassManager = CompassManager()
    @State private var displayedAngle: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            ZStack {
                // Círculo de fondo
                Circle()
                    .stroke(Color.gray, lineWidth: 4)
                    .frame(width: 200, height: 200)

                // Flecha que apunta hacia la dirección del destino
                ArrowShape()
                    .fill(Color.red)
                    .frame(width: 20, height: 100)
                    .offset(y: -50)
                    .rotationEffect(Angle(degrees: displayedAngle))
                    .animation(.easeInOut(duration: 0.2), value: displayedAngle)
            }


        }
        .padding()
        .onReceive(compassManager.$heading) { _ in
            displayedAngle = compassManager.shortestRotation(from: displayedAngle, to: compassManager.anguloRelativo)
        }
    }
}






// MARK: - Forma de la flecha
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let topY = rect.minY
        let bottomY = rect.maxY
        let width = rect.width

        path.move(to: CGPoint(x: midX, y: topY))
        path.addLine(to: CGPoint(x: midX + width / 2, y: bottomY))
        path.addLine(to: CGPoint(x: midX - width / 2, y: bottomY))
        path.closeSubpath()

        return path
    }
}






// MARK: - Controlador de brújula con destino y rotación continua
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()

    @Published var heading: CLHeading?
    @Published var direccionDestino: CLLocationDirection = 90  // Por defecto: Este
    @Published var anguloRelativo: Double = 0

    private var haVibrado = false  // Bandera para controlar la vibración

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
        DispatchQueue.main.async {
            self.heading = newHeading

            let headingActual = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            let nuevoRelativo = self.diferenciaAngular(desde: headingActual, hasta: self.direccionDestino)

            // Vibrar si el ángulo relativo es cercano a 0° (con tolerancia ±5°), y no ha vibrado recientemente
            if (abs(nuevoRelativo) < 2 || abs(nuevoRelativo - 360) < 2) {
                if !self.haVibrado {
                    Haptics.vibrar()
                    self.haVibrado = true
                }
            } else {
                // Si el usuario se aleja del rango, se reinicia la posibilidad de vibrar
                self.haVibrado = false
            }

            self.anguloRelativo = self.shortestRotation(from: self.anguloRelativo, to: nuevoRelativo)
        }
    }

    private func diferenciaAngular(desde origen: CLLocationDirection, hasta destino: CLLocationDirection) -> Double {
        let diff = fmod((destino - origen + 360), 360)
        return diff
    }

    func shortestRotation(from oldAngle: Double, to newAngle: Double) -> Double {
        let delta = fmod((newAngle - oldAngle + 540), 360) - 180
        return oldAngle + delta
    }
}






// MARK: - Vibración
class Haptics {
    static func vibrar() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

