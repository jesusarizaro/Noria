import CoreLocation

// Esta clase es responsable de acceder al GPS del teléfono.
// Nos dice dónde está el usuario en coordenadas reales.
class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    // Este es el objeto que accede al hardware del GPS.
    private let manager = CLLocationManager()

    // Esta variable contiene la última ubicación detectada.
    // Es "@Published" para que otras partes de la app puedan reaccionar cuando cambie.
    @Published var currentLocation: CLLocation?

    // Este es el constructor de la clase, se ejecuta cuando se crea el objeto LocationManager.
    override init() {
        super.init()
        manager.delegate = self // Le decimos que nosotros (esta clase) vamos a manejar las respuestas del GPS.
        manager.desiredAccuracy = kCLLocationAccuracyBest // Le pedimos la mejor precisión posible.
        manager.requestWhenInUseAuthorization() // Le pedimos permiso al usuario para usar el GPS.
        manager.startUpdatingLocation() // Empezamos a recibir actualizaciones de ubicación.
    }

    // Esta función se llama cada vez que el GPS detecta una nueva ubicación.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // Guardamos la última ubicación detectada en nuestra variable.
            currentLocation = location
            print("Ubicación obtenida: \(location.coordinate)") // Esto se imprime en la consola para ver la latitud y longitud.
        }
    }

    // Esta función se llama si ocurre un error al intentar obtener la ubicación.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error al obtener ubicación: \(error)")
    }
}  
