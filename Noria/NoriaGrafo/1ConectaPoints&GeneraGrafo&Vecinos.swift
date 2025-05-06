import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var output = "Cargando grafo..."

    var body: some View {
        ScrollView {
            Text(output)
                .padding()
                .font(.system(size: 14, design: .monospaced))
        }
        .onAppear {
            let grafo = GeoJSONGraphBuilder.buildGraph(from: "SimpleLayers")
            output = exportarGrafoComoTexto(grafo)
        }
    }

    func exportarGrafoComoTexto(_ grafo: Graph) -> String {
        var texto = ""
        for vertex in grafo.vertices.values {
            let key = "\(vertex.coordinate.latitude),\(vertex.coordinate.longitude)"
            let nombre = vertex.name ?? "-"
            let vecinos = vertex.neighbors.map {
                "\($0.coordinate.latitude),\($0.coordinate.longitude)"
            }
            texto += "🔹 \(nombre) [\(key)] → \(vecinos.joined(separator: ", "))\n"
        }
        return texto
    }
}

// ================================
// 👇 A continuación va el código del grafo
// ================================

class Vertex: Hashable {
    let coordinate: CLLocationCoordinate2D
    var name: String?
    var neighbors: [Vertex] = []

    init(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        self.coordinate = coordinate
        self.name = name
    }

    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
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
        return "\(coordinate.latitude),\(coordinate.longitude)"
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
}

class GeoJSONGraphBuilder {
    static func buildGraph(from SimpleLayers: String) -> Graph {
        let grafo = Graph()

        guard let url = Bundle.main.url(forResource: SimpleLayers, withExtension: "geojson"),
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
