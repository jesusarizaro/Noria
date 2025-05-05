import SwiftUI
import RealityKit
import ARKit
import Speech
import MapKit

struct ContentView: View {
    @StateObject private var recognizer = SpeechRecognizer()
    @State private var socketService = SocketManagerService()
    @State private var showMap = false

    var body: some View {
        ZStack(alignment: .top) {
            ARViewContainer()

            VStack(spacing: 12) {
                Button(action: {
                    showMap.toggle()
                }) {
                    Text("🌍 Mapa")
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 30)

                Text("📣: \(recognizer.recognizedText)")
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button("🎤 Hablar") {
                        recognizer.startRecording()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("📤 Enviar") {
                        socketService.sendMessage(recognizer.recognizedText)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                VStack(alignment: .leading) {
                    Text("📤 Mensajes Enviados")
                        .font(.headline)
                        .padding(.leading)

                    ScrollView {
                        ForEach(socketService.sentMessages, id: \.self) { msg in
                            Text(msg)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                    .frame(height: 100)
                }

                VStack(alignment: .leading) {
                    Text("🧠 Respuestas del Servidor")
                        .font(.headline)
                        .padding(.leading)

                    ScrollView {
                        ForEach(socketService.receivedMessages, id: \.self) { msg in
                            Text(msg)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                    .frame(height: 100)
                }
            }

            if showMap {
                MapOverlayView(showMap: $showMap)
                    .transition(.move(edge: .top))
                    .zIndex(1)
            }

        }
        .edgesIgnoringSafeArea(.all)
    }
}
