import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            CameraView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Detección de Personas")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 50)
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}

