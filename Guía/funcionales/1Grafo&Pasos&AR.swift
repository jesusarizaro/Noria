import SwiftUI
import MapKit
import CoreLocation
import Combine
import AVFoundation
import RealityKit
import ARKit

//MARK: - inApp: ContentView
struct ContentView: View {
    @State private var showMap = true
    @State private var grafo = Graph()
    @State private var puntosConNombre: [Vertex] = []
    @State private var nombreFin: String = ""
    @State private var resultadoRuta = "Selecciona destino y calcula la ruta desde tu ubicación."
    @State private var grafoRuta: [Vertex] = []
    @State private var rutaAnalizada: [AristaInfo] = []
    @State private var giroActual = ""
    @State private var distanciaHastaProximo = ""
    @State private var aristaActualIndex = 0
    @StateObject private var locationManager = LocationManager()
    @StateObject private var compassManager = CompassManager()
    @State private var ultimaInstruccion = ""
    @State private var tiempoUltimaInstruccion = Date(timeIntervalSince1970: 0)
    let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            // Cámara AR de fondo
            ARCameraView()

            // Mostrar interfaz del mapa si está activado
            if showMap {
                VStack(spacing: 40) {
                    Spacer()

                    MapView(
                        ruta: grafoRuta.map { $0.coordinate },
                        puntos: puntosConNombre,
                        userLocation: locationManager.userLocation
                    )
                    .frame(width: 400, height: 300)
                    .cornerRadius(10)

                    Text("Selecciona punto de destino")
                        .font(.subheadline)

                    Picker("Destino", selection: $nombreFin) {
                        ForEach(puntosConNombre.compactMap({ $0.name }), id: \.self) { nombre in
                            Text(nombre)
                        }
                    }
                    .pickerStyle(.wheel)

                    VStack(spacing: 8) {
                        Text("🚶‍♂️ \(distanciaHastaProximo)")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("🔄 Instrucción actual: \(giroActual)")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    .padding()

                    ScrollView {
                        Text(resultadoRuta)
                            .padding()
                            .font(.system(size: 14, design: .monospaced))
                    }

                    HStack(spacing: 20) {
                        Button("📷 Cámara") {
                            showMap = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("👩🏻‍🦯‍➡️ Calcular ruta") {
                            calcularRuta()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
                .onReceive(locationManager.$userLocation.compactMap { $0 }) { _ in
                    verificarGiros()
                }
            } else {
                VStack {
                    Spacer()
                    Button("🗺️ Mapa") {
                        showMap = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            cargarGrafo()
        }
    }








    
    
    
    
    
    
    
    

    func cargarGrafo() {
        grafo = GeoJSONGraphBuilder.buildGraph(from: "ComplexLayers")
        puntosConNombre = grafo.vertices.values.filter { $0.name != nil }
        if let primero = puntosConNombre.first {
            nombreFin = primero.name ?? ""
        }
    }

    func calcularRuta() {
        guard let gps = locationManager.userLocation else {
            resultadoRuta = "❌ Esperando señal GPS..."
            return
        }

        guard let destino = grafo.vertices.values.first(where: { $0.name == nombreFin }),
              let inicio = verticeMasCercano(a: gps),
              let ruta = grafo.shortestPath(from: inicio.coordinate, to: destino.coordinate) else {
            resultadoRuta = "❌ No se pudo calcular ruta desde tu ubicación"
            grafoRuta = []
            return
        }

        resultadoRuta = ruta.map { $0.name ?? grafo.key(for: $0.coordinate) }
                            .joined(separator: " → ")
        grafoRuta = ruta

        rutaAnalizada = []
        for i in 0..<ruta.count - 1 {
            let origen = ruta[i].coordinate
            let destino = ruta[i + 1].coordinate

            let distancia = CLLocation(latitude: origen.latitude, longitude: origen.longitude)
                .distance(from: CLLocation(latitude: destino.latitude, longitude: destino.longitude))
            let distanciaPies = distancia * 3.28084

            let deltaLat = destino.latitude - origen.latitude
            let deltaLon = destino.longitude - origen.longitude
            let radians = atan2(deltaLon, deltaLat)
            let degrees = (radians * 180 / .pi).truncatingRemainder(dividingBy: 360)
            let orientacion = (degrees >= 0) ? degrees : degrees + 360

            let info = AristaInfo(inicio: origen, fin: destino, pies: distanciaPies, orientacion: orientacion)
            rutaAnalizada.append(info)
        }
        aristaActualIndex = 0
    }

    func verificarGiros() {
        guard let ubicacionActual = locationManager.userLocation,
              aristaActualIndex < rutaAnalizada.count else { return }

        let arista = rutaAnalizada[aristaActualIndex]
        let distancia = CLLocation(latitude: ubicacionActual.latitude, longitude: ubicacionActual.longitude)
            .distance(from: CLLocation(latitude: arista.fin.latitude, longitude: arista.fin.longitude))

        distanciaHastaProximo = String(format: "%.0f pies hasta próximo giro", distancia * 3.28084)

        if distancia < 8.0 {
            if aristaActualIndex < rutaAnalizada.count - 1 {
                let orientacionEsperada = rutaAnalizada[aristaActualIndex + 1].orientacion
                let orientacionUsuario = compassManager.heading
                let diferencia = normalizarAngulo(orientacionEsperada - orientacionUsuario)

                var instruccion = ""
                if diferencia > 30 {
                    instruccion = "Gira a la derecha"
                } else if diferencia < -30 {
                    instruccion = "Gira a la izquierda"
                } else {
                    instruccion = "Sigue recto"
                }

                if instruccion != ultimaInstruccion || Date().timeIntervalSince(tiempoUltimaInstruccion) > 8 {
                    ultimaInstruccion = instruccion
                    tiempoUltimaInstruccion = Date()
                    giroActual = instruccion
                }
            }
            aristaActualIndex += 1
        }
    }

    func normalizarAngulo(_ angulo: Double) -> Double {
        var a = angulo
        while a < -180 { a += 360 }
        while a > 180 { a -= 360 }
        return a
    }

    func verticeMasCercano(a coordenada: CLLocationCoordinate2D) -> Vertex? {
        grafo.vertices.values.min(by: {
            let d1 = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude))
            let d2 = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude))
            return d1 < d2
        })
    }
}

// MARK: - Vista que muestra la cámara con ARKit como fondo
struct ARCameraView: View {
    var body: some View {
        ZStack {
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

// MARK: - inApp: Cámara AR como fondo fijo
struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}













//MARK: - inApp: DESPLIEGA EL MAPA
struct MapView: UIViewRepresentable {
    var ruta: [CLLocationCoordinate2D]
    var puntos: [Vertex]
    var userLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        return mapView
    }

    
    
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.removeOverlays(mapView.overlays)

        for punto in puntos {
            let annotation = MKPointAnnotation()
            annotation.coordinate = punto.coordinate
            annotation.title = punto.name
            mapView.addAnnotation(annotation)
        }

        if ruta.count > 1 {
            let polyline = MKPolyline(coordinates: ruta, count: ruta.count)
            mapView.addOverlay(polyline)

            let region = MKCoordinateRegion(
                center: ruta[ruta.count / 2],
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
            mapView.setRegion(region, animated: true)
        } else if let userLoc = userLocation {
            let region = MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}



//MARK: - 6. BRÚJULA
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



//MARK: - 5. DICCIONARIO DE ARISTAS (LineString)
struct AristaInfo: Identifiable {
    let id = UUID()
    let inicio: CLLocationCoordinate2D
    let fin: CLLocationCoordinate2D
    let pies: Double
    let orientacion: Double
}



// MARK: - 4. CLASE GRAPH (dijkstra)
class Graph {
    
    // MARK: Resumen: 4. CLASE GRAPH
    //1. Busca el vértice start y end por su name.
    //2. Inicia un diccionario distances para guardar la distancia más corta conocida desde el inicio a cada nodo.
    //2.1 Al principio, todos tienen .infinity, menos el inicio (distancia = 0).
    //3. Usa un Set de nodos unvisited para saber a cuáles todavía no hemos llegado.
    //4. En cada ciclo:
    //  4.1 Busca el nodo no visitado con menor distancia conocida.
    //  4.2 Lo marca como visitado (lo saca del set).
    //  4.3Para cada vecino:
    //      4.3.1 Calcula una distancia tentativa.
    //      4.3.2 Si es más corta que la actual, actualiza.
    //5. Si llega al nodo final (end), reconstruye el camino usando previous[].
    // MARK: Resultado: LO QUE APORTA ESTA CLASE AL CODE ES --> Graph
    
    //esta variable es un diccionario de vertices
    var vertices: [String: Vertex] = [:]

    //convierte las coordenadas en un texto
    func key(for coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }

    //función que busca si ya existe un vértice en una ubicación
    //si sí, lo devuelve
    //si no, lo crea y lo agrega al diccionario de vertices
    func getOrCreateVertex(for coordinate: CLLocationCoordinate2D, name: String? = nil) -> Vertex {
        let k = key(for: coordinate)
        if let existente = vertices[k] {
            if let nuevoNombre = name {
                existente.name = nuevoNombre
            }
            return existente
        } else {
            let vertice = Vertex(coordinate: coordinate, name: name)
            vertices[k] = vertice
            return vertice
        }
    }

    //conecta dos puntos del grafo
    func connect(_ v1: Vertex, _ v2: Vertex) {
        if !v1.neighbors.contains(v2) {
            v1.neighbors.append(v2)
        }
        if !v2.neighbors.contains(v1) {
            v2.neighbors.append(v1)
        }
    }

    //encuentra la ruta más corta entre dos puntos por nombre
    //algoritmo Dijkstra
    func shortestPath(from startCoord: CLLocationCoordinate2D, to endCoord: CLLocationCoordinate2D) -> [Vertex]? {
        let start = getOrCreateVertex(for: startCoord)
        let end = getOrCreateVertex(for: endCoord)
        
        var distances: [Vertex: Double] = [:]
        var previous: [Vertex: Vertex] = [:]
        var unvisited: Set<Vertex> = Set(vertices.values)

        for vertex in unvisited {
            distances[vertex] = .infinity
        }
        distances[start] = 0

        while !unvisited.isEmpty {
            let current = unvisited.min { distances[$0, default: .infinity] < distances[$1, default: .infinity] }!
            unvisited.remove(current)

            if current == end {
                var path: [Vertex] = []
                var u: Vertex? = end
                while let actual = u {
                    path.insert(actual, at: 0)
                    u = previous[actual]
                }
                return path
            }

            for neighbor in current.neighbors {
                if !unvisited.contains(neighbor) { continue }
                let tentative = distances[current, default: .infinity] + distance(from: current, to: neighbor)
                if tentative < distances[neighbor, default: .infinity] {
                    distances[neighbor] = tentative
                    previous[neighbor] = current
                }
            }
        }
        return nil
    }
    private func distance(from v1: Vertex, to v2: Vertex) -> Double {
        let loc1 = CLLocation(latitude: v1.coordinate.latitude, longitude: v1.coordinate.longitude)
        let loc2 = CLLocation(latitude: v2.coordinate.latitude, longitude: v2.coordinate.longitude)
        return loc1.distance(from: loc2)
    }
}



// MARK: - 3. CLASE VERTEX
class Vertex: Hashable, Identifiable {
    
    // MARK: Resumen: 2. CLASE VERTEX
    //aquí considera iguales los vértices que compartan una misma coordenada
    //posibles conexiones con otros vértices vecinos
    // MARK: Resultado: LO QUE APORTA ESTA CLASE AL CODE ES --> Vertex
    
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var name: String?
    var neighbors: [Vertex] = []

    init(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        self.coordinate = coordinate
        self.name = name
    }

    //esto define cuándo dos vértices son iguales
    //se consideran iguales si tienen la misma latitud y longitud
    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    //permite que dos vértices con la misma ubicación geográfica tengan el mismo hash
    //útil para que funcionen bien en sets.
    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}



// MARK: - 2. CLASE QUE CONSTRUYE EL GRAFO DADO UN .geojson
class GeoJSONGraphBuilder {
    
    // MARK: Resumen: 1. CLASE QUE CONSTRUYE EL GRAFO DADO UN .geojson
    //busca el archivo .geojson indicado en el proyecto
    //saca información del archivo
    //se va a "features" del archivo para clasificar LineString o Points
    //toda coordenada que encuentra la hace un vértice
    // MARK: Resultado: LO QUE APORTA ESTA CLASE AL CODE ES --> let grafo = Graph()
    
    //llama al archivo .geojson
    static func buildGraph(from ComplexLayers: String) -> Graph {
        let grafo = Graph()

        //se prepara para construir el grafo
        //busca dentro de los archivos del proyecto el nombre del .geojson
        guard let url = Bundle.main.url(forResource: ComplexLayers, withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            print("❌ Error al leer el archivo GeoJSON")
            //da el grafo construido
            return grafo
        }

        //para la variable "features" del hilo de arriba
        for feature in features {
            //fragmenta la información de .geojson
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }

            //va a empezar a clasificar si es una LINESTRING o un Point
            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] {
                //va a fragmentar cada LineString por la cantidad de coordenadas que la conformen
                var prevVertex: Vertex?
                //cada coordenada la convertirá en un vértice
                for coord in coords {
                    //toma cada coordenada de LineString
                    let punto = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    let vertice = grafo.getOrCreateVertex(for: punto)
                    if let anterior = prevVertex {
                        grafo.connect(anterior, vertice)
                    }
                    //conversión de coordenadas de un LineString a vértices del grafo
                    prevVertex = vertice
                }
            }

            //va a empezar a clasificar si es una LineString o un POINT
            if type == "Point", let coord = geometry["coordinates"] as? [Double] {
                let punto = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                let nombre = (feature["properties"] as? [String: Any])?["name"] as? String
                _ = grafo.getOrCreateVertex(for: punto, name: nombre)
            }
        }
        return grafo
    }
}



// MARK: - 1. CLASE LocationManager GPS
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }
}
