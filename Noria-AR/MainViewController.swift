import UIKit
import ARKit
import SceneKit
import CoreLocation
import AVFoundation
import Speech

class MainViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    var sceneView: ARSCNView!
    var locationManager = CLLocationManager()
    var breadcrumbManager = BreadcrumbManager()
    var voiceManager = VoiceManager()
    var speechSynthesizer = SpeechSynthesizerManager()

    var modoGrabacion = false
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Crear la cámara AR
        sceneView = ARSCNView(frame: self.view.frame)
        sceneView.delegate = self
        self.view.addSubview(sceneView)

        configurarAR()
        configurarLocation()
        voiceManager.solicitarPermisos()
        breadcrumbManager.inicializar(sceneView: sceneView)

        configurarBotones()
    }

    func configurarAR() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
    }

    func configurarLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }

    func configurarBotones() {
        let anchoBoton: CGFloat = 250
        let altoBoton: CGFloat = 50

        // Botón Iniciar Grabación
        let botonIniciar = UIButton(frame: CGRect(x: (view.frame.width - anchoBoton)/2,
                                                   y: view.frame.height - 240,
                                                   width: anchoBoton,
                                                   height: altoBoton))
        botonIniciar.backgroundColor = UIColor.systemGreen
        botonIniciar.setTitle("Iniciar Grabación", for: .normal)
        botonIniciar.addTarget(self, action: #selector(comenzarGrabacion), for: .touchUpInside)
        botonIniciar.layer.cornerRadius = 10
        self.view.addSubview(botonIniciar)

        // Botón Detener Grabación
        let botonDetener = UIButton(frame: CGRect(x: (view.frame.width - anchoBoton)/2,
                                                   y: view.frame.height - 170,
                                                   width: anchoBoton,
                                                   height: altoBoton))
        botonDetener.backgroundColor = UIColor.systemRed
        botonDetener.setTitle("Detener Grabación", for: .normal)
        botonDetener.addTarget(self, action: #selector(detenerGrabacion), for: .touchUpInside)
        botonDetener.layer.cornerRadius = 10
        self.view.addSubview(botonDetener)

        // Botón Iniciar Navegación
        let botonNavegar = UIButton(frame: CGRect(x: (view.frame.width - anchoBoton)/2,
                                                   y: view.frame.height - 100,
                                                   width: anchoBoton,
                                                   height: altoBoton))
        botonNavegar.backgroundColor = UIColor.systemBlue
        botonNavegar.setTitle("Iniciar Navegación", for: .normal)
        botonNavegar.addTarget(self, action: #selector(iniciarNavegacion), for: .touchUpInside)  // AQUÍ es donde va tu línea
        botonNavegar.layer.cornerRadius = 10
        self.view.addSubview(botonNavegar)
    }

    @objc func comenzarGrabacion() {
        modoGrabacion = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.breadcrumbManager.agregarMigaDePan()
        }
        speechSynthesizer.hablar(mensaje: "Comenzando grabación del recorrido.")
    }

    @objc func detenerGrabacion() {
        modoGrabacion = false
        timer?.invalidate()
        timer = nil

        guard !breadcrumbManager.migasDePan.isEmpty else {
            speechSynthesizer.hablar(mensaje: "No se grabó ningún recorrido.")
            return
        }

        let nombreRecorrido = "\(breadcrumbManager.contadorRecorridos)"
        breadcrumbManager.guardarRecorridoEnArchivo(nombre: nombreRecorrido)
        breadcrumbManager.eliminarTodasLasMigas()
        breadcrumbManager.contadorRecorridos += 1

        speechSynthesizer.hablar(mensaje: "Recorrido número \(nombreRecorrido) guardado correctamente.")
    }






    @objc func iniciarNavegacion() {
        let archivos = obtenerListaArchivos()

        if archivos.isEmpty {
            speechSynthesizer.hablar(mensaje: "No hay recorridos guardados.")
            return
        }

        let alerta = UIAlertController(title: "Elige un recorrido", message: nil, preferredStyle: .actionSheet)

        for nombre in archivos {
            alerta.addAction(UIAlertAction(title: "Recorrido \(nombre)", style: .default, handler: { _ in
                self.breadcrumbManager.cargarRecorridoDesdeArchivo(nombre: nombre)
                self.speechSynthesizer.hablar(mensaje: "Recorrido \(nombre) cargado. Sigue las esferas rojas para navegar.")
            }))
        }

        alerta.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))

        if let topController = UIApplication.shared.windows.first?.rootViewController {
            topController.present(alerta, animated: true, completion: nil)
        }
    }


    func obtenerListaArchivos() -> [String] {
        let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let carpeta = documentos.appendingPathComponent("Recorridos")
        do {
            let archivos = try FileManager.default.contentsOfDirectory(atPath: carpeta.path)
            let nombres = archivos.map { $0.replacingOccurrences(of: ".json", with: "") }
            return nombres.sorted { Int($0)! < Int($1)! }
        } catch {
            print("Error listando recorridos: \(error)")
            return []
        }
    }




    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        breadcrumbManager.renderizarMiga(node: node, anchor: anchor)
    }
}

