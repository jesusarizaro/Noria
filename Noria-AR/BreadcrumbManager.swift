//
//  BreadcrumbManager.swift
//  Noria-AR
//
//  Created by Jesus Ariza on 2025-04-12.
//

import ARKit
import SceneKit

struct MigaGuardada: Codable {
    let x: Float
    let y: Float
    let z: Float
}


class BreadcrumbManager {
    var sceneView: ARSCNView?
    var migasDePan: [ARAnchor] = []
    var recorridosGuardados: [String: [ARAnchor]] = [:]
    var contadorRecorridos = 1

    private var nodosAnclados: [SCNNode] = [] // Para eliminar nodos después

    func inicializar(sceneView: ARSCNView) {
        self.sceneView = sceneView
    }

    func agregarMigaDePan() {
        guard let frame = sceneView?.session.currentFrame else { return }
        let transform = frame.camera.transform
        let anchor = ARAnchor(transform: transform)
        sceneView?.session.add(anchor: anchor)
        migasDePan.append(anchor)
    }

    func renderizarMiga(node: SCNNode, anchor: ARAnchor) {
        let esfera = SCNSphere(radius: 0.05)
        esfera.firstMaterial?.diffuse.contents = UIColor.red
        let nodoEsfera = SCNNode(geometry: esfera)
        node.addChildNode(nodoEsfera)
        nodosAnclados.append(node) // Guardamos los nodos para borrarlos después
    }

    func eliminarTodasLasMigas() {
        for nodo in nodosAnclados {
            nodo.removeFromParentNode()
        }
        nodosAnclados.removeAll()
        migasDePan.removeAll()
    }

    func guardarRecorridoEnArchivo(nombre: String) {
        let posiciones = migasDePan.map { anchor -> MigaGuardada in
            let pos = anchor.transform.columns.3
            return MigaGuardada(x: pos.x, y: pos.y, z: pos.z)
        }

        do {
            let data = try JSONEncoder().encode(posiciones)
            let url = obtenerURLRecorrido(nombre: nombre)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            print("Recorrido guardado en: \(url)")
        } catch {
            print("Error guardando recorrido: \(error)")
        }
    }

    func obtenerURLRecorrido(nombre: String) -> URL {
        let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentos.appendingPathComponent("Recorridos/\(nombre).json")
    }

    func cargarRecorridoDesdeArchivo(nombre: String) {
        do {
            let url = obtenerURLRecorrido(nombre: nombre)
            let data = try Data(contentsOf: url)
            let posiciones = try JSONDecoder().decode([MigaGuardada].self, from: data)

            eliminarTodasLasMigas()

            for pos in posiciones {
                var transform = matrix_identity_float4x4
                transform.columns.3 = SIMD4<Float>(pos.x, pos.y, pos.z, 1)
                let anchor = ARAnchor(transform: transform)
                sceneView?.session.add(anchor: anchor)
                migasDePan.append(anchor)
            }
            print("Recorrido \(nombre) cargado.")
        } catch {
            print("Error cargando recorrido: \(error)")
        }
    }
}
