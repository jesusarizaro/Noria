import Foundation
import SocketIO

class SocketManagerService: ObservableObject {
    private var manager: SocketManager
    private var socket: SocketIOClient

    @Published var messages: [String] = []
    @Published var sentMessages: [String] = []
    @Published var receivedMessages: [String] = []


    init() {
        let url = URL(string: "http://172.210.67.108:5000")!
        manager = SocketManager(socketURL: url, config: [.log(true), .compress])
        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { _, _ in
            print("✅ Conectado al servidor")
        }

        socket.on("message") { data, _ in
            if let msg = data.first as? String {
                DispatchQueue.main.async {
                    self.receivedMessages.append("🧠 Servidor: \(msg)")
                }
            }
        }


        socket.connect()
    }

    func sendMessage(_ text: String) {
        socket.emit("message", text)
        DispatchQueue.main.async {
            self.sentMessages.append("📲 Yo: \(text)")
        }
    }

}
