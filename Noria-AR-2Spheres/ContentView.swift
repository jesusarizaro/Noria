import SwiftUI

// Esta es la vista principal de la aplicación.
// Aquí colocamos el espacio de realidad aumentada y un botón para activar la colocación de la esfera.
struct ContentView: View {
    
    // Esta variable controla si se deben colocar o no las esferas en el mundo AR.
    // Está conectada al botón.
    @State private var shouldPlaceAnchors = false

    var body: some View {
        VStack {
            
            // ARViewContainer es la vista que muestra la cámara y el espacio AR.
            // Se le pasa la variable shouldPlaceAnchors para saber cuándo colocar la esfera.
            ARViewContainer(shouldPlaceAnchors: $shouldPlaceAnchors)
                .edgesIgnoringSafeArea(.all)

            // Botón que el usuario puede presionar para colocar la esfera.
            Button(action: {
                // Cada vez que se presiona, se cambia el valor de shouldPlaceAnchors.
                // Eso hace que la vista AR se actualice y coloque la esfera.
                shouldPlaceAnchors.toggle()
            }) {
                // Aquí diseñamos cómo se ve el botón (texto, color, forma, etc.)
                Text("📍 Colocar Esferas")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            // Espacio alrededor del botón
            .padding()
        }
    }
}
