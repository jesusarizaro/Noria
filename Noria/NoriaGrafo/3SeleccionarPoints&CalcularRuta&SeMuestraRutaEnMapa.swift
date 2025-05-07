import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var grafo = Graph()
    @State private var puntosConNombre: [Vertex] = []
    @State private var puntoInicio: Vertex?
    @State private var puntoFin: Vertex?
    @State private var resultadoRuta = "Selecciona dos puntos y calcula la ruta."
    @State private var grafoRuta: [Vertex] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Selecciona punto de inicio")
            Picker("Inicio", selection: $puntoInicio) {
                ForEach(puntosConNombre) { punto in
                    Text(punto.name ?? "-")
                }
            }
            .pickerStyle(.wheel)

            Text("Selecciona punto de fin")
            Picker("Destino", selection: $puntoFin) {
                ForEach(puntosConNombre) { punto in
                    Text(punto.name ?? "-")
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
                puntos: puntosConNombre
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
        grafo = GeoJSONGraphBuilder.buildGraph(from: "SimpleLayers")
        puntosConNombre = grafo.vertices.values.filter { $0.name != nil }
        if puntosConNombre.count >= 2 {
            puntoInicio = puntosConNombre[0]
            puntoFin = puntosConNombre[1]
        }
    }

    func calcularRuta() {
        guard let inicio = puntoInicio?.name,
              let fin = puntoFin?.name,
              let ruta = grafo.shortestPath(from: inicio, to: fin) else {
            resultadoRuta = "❌ No se encontró ruta entre los puntos seleccionados"
            grafoRuta = []
            return
        }

        resultadoRuta = ruta.map { $0.name ?? grafo.key(for: $0.coordinate) }
                            .joined(separator: " → ")
        grafoRuta = ruta
        print("🟢 Ruta encontrada: \(resultadoRuta)")
    }
}

// MARK: - MapView integrado

struct MapView: UIViewRepresentable {
    var ruta: [CLLocationCoordinate2D]
    var puntos: [Vertex]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
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

// MARK: - Clases del grafo

class Vertex: Hashable, Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var name: String?
    var neighbors: [Vertex] = []

    init(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        self.coordinate = coordinate
        self.name = name
    }

    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

class Graph {
    var vertices: [String: Vertex] = [:]

    func key(for coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }

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

    func connect(_ v1: Vertex, _ v2: Vertex) {
        if !v1.neighbors.contains(v2) {
            v1.neighbors.append(v2)
        }
        if !v2.neighbors.contains(v1) {
            v2.neighbors.append(v1)
        }
    }

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

class GeoJSONGraphBuilder {
    static func buildGraph(from fileName: String) -> Graph {
        let grafo = Graph()

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            print("❌ Error al leer el archivo GeoJSON")
            return grafo
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }

            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] {
                var prevVertex: Vertex?
                for coord in coords {
                    let punto = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    let vertice = grafo.getOrCreateVertex(for: punto)
                    if let anterior = prevVertex {
                        grafo.connect(anterior, vertice)
                    }
                    prevVertex = vertice
                }
            }

            if type == "Point", let coord = geometry["coordinates"] as? [Double] {
                let punto = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                let nombre = (feature["properties"] as? [String: Any])?["name"] as? String
                _ = grafo.getOrCreateVertex(for: punto, name: nombre)
            }
        }

        return grafo
    }
}
