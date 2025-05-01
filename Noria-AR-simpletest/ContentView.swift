import SwiftUI

struct ContentView: View {
    @State private var shouldPlaceAnchors = false

    var body: some View {
        VStack {
            ARViewContainer(shouldPlaceAnchors: $shouldPlaceAnchors)
                .edgesIgnoringSafeArea(.all)

            Button(action: {
                shouldPlaceAnchors.toggle()
            }) {
                Text("📍 Colocar Esferas")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }
}
