// ✅ Agrega esto al comienzo del archivo:
import SwiftUI
import MapKit
import CoreLocation

// ✅ LocationManager: obtiene GPS en vivo
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

// ✅ ContentView con GPS como punto de inicio
struct ContentView: View {
    @State private var grafo = Graph()
    @State private var puntosConNombre: [Vertex] = []

    @State private var nombreFin: String = ""
    @State private var resultadoRuta = "Selecciona destino y calcula la ruta desde tu ubicación."
    @State private var grafoRuta: [Vertex] = []

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Selecciona punto de destino")
            Picker("Destino", selection: $nombreFin) {
                ForEach(puntosConNombre.compactMap({ $0.name }), id: \ .self) { nombre in
                    Text(nombre)
                }
            }
            .pickerStyle(.wheel)

            Button("Calcular ruta") {
                calcularRuta()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            ScrollView {
                Text(resultadoRuta)
                    .padding()
                    .font(.system(size: 14, design: .monospaced))
            }

            MapView(
                ruta: grafoRuta.map { $0.coordinate },
                puntos: puntosConNombre,
                userLocation: locationManager.userLocation
            )
            .frame(height: 300)
            .cornerRadius(10)
        }
        .padding()
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
              let ruta = grafo.shortestPath(from: inicio.name ?? grafo.key(for: inicio.coordinate),
                                            to: destino.name ?? grafo.key(for: destino.coordinate)) else {
            resultadoRuta = "❌ No se pudo calcular ruta desde tu ubicación"
            grafoRuta = []
            return
        }

        resultadoRuta = ruta.map { $0.name ?? grafo.key(for: $0.coordinate) }
                            .joined(separator: " → ")
        grafoRuta = ruta
        print("📍 Tu ubicación GPS: \(gps.latitude), \(gps.longitude)")
        print("🟢 Ruta encontrada: \(resultadoRuta)")
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

// ✅ Mapa con punto azul como en Find My
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

// 🔐 Agrega a Info.plist:
// <key>NSLocationWhenInUseUsageDescription</key>
// <string>Necesitamos tu ubicación para calcular rutas</string>









// MARK: - 1. CLASE QUE CONSTRUYE EL GRAFO DADO UN .geojson
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



// MARK: - 2. CLASE VERTEX
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



// MARK: - 3. CLASE GRAPH (dijkstra)
class Graph {
    
    // MARK: Resumen: 3. CLASE GRAPH
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
    func shortestPath(from startName: String, to endName: String) -> [Vertex]? {
        guard let start = vertices.values.first(where: { $0.name == startName }),
              let end = vertices.values.first(where: { $0.name == endName }) else {
            print("❌ No se encontró alguno de los puntos")
            return nil
        }

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
