import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedStart: String = ""
    @State private var selectedEnd: String = ""
    @State private var showAR = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Selecciona los puntos:")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Inicio")
                    Picker("Inicio", selection: $selectedStart) {
                        ForEach(viewModel.points, id: \.name) { point in
                            Text(point.name).tag(point.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                VStack(alignment: .leading) {
                    Text("Destino")
                    Picker("Fin", selection: $selectedEnd) {
                        ForEach(viewModel.points, id: \.name) { point in
                            Text(point.name).tag(point.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            Button("Mostrar ruta en AR") {
                viewModel.calcularRutaPorNombre(startName: selectedStart, endName: selectedEnd)
                showAR = true
            }
            .disabled(selectedStart.isEmpty || selectedEnd.isEmpty)

            Spacer()
        }
        .sheet(isPresented: $showAR) {
            ARViewContainer(routeCoordinates: viewModel.subrutaPolyline.coordinates)
                .edgesIgnoringSafeArea(.all)
        }
        .padding()
        .onAppear {
            viewModel.loadGeoJSON()
        }
    }
}
