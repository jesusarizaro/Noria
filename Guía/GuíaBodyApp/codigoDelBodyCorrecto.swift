import SwiftUI
import MapKit
import CoreLocation
import Combine
import AVFoundation

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
            // Fondo: siempre la cámara AR
            ARViewContainer()

            // Si showMap es true, se sobrepone la interfaz del mapa con fondo negro
            if showMap {
                VStack(spacing: 5) {
                    Spacer()

// Mapa en el centro
                    MapView(
                        ruta: grafoRuta.map { $0.coordinate },
                        puntos: puntosConNombre,
                        userLocation: locationManager.userLocation
                    )
                        .frame(width: 400, height: 300)
                        .cornerRadius(10)
                    
                    
                    
                    
                    
                    
//Seleccionar destino
                    Text("Selecciona punto de destino")
                    Picker("Destino", selection: $nombreFin) {
                        ForEach(puntosConNombre.compactMap({ $0.name }), id: \ .self) { nombre in
                            Text(nombre)
                        }
                    }
                    .pickerStyle(.menu)


                    
//Pies y Giros
                    VStack(spacing: 8) {
                        Text("🚶‍♂️ \(distanciaHastaProximo)")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("🔄 Instrucción actual: \(giroActual)")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    .padding()

                    
//Ruta
                    ScrollView {
                        Text(resultadoRuta)
                            .padding()
                            .font(.system(size: 14, design: .monospaced))
                    }
                    
                    
                    
                    
                    
                    
                    
                    
                    

                    
                    
                    
                    
// Botones: Cámara y Calcular ruta
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
                .background(Color.black) // Fondo negro para ocultar la cámara
                .edgesIgnoringSafeArea(.all)
                
                
                
                
                
                
            } else {
                // Botón para volver al mapa
                VStack {
                    Spacer()
                    Button("🗺️ Mapa") {
                        showMap = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(0)

                }
            }
        }
        
        
        
        
        
        
        
        
        
        
        
        .edgesIgnoringSafeArea(.all)
    }
