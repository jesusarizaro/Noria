import SwiftUI
import MapKit

struct MapOverlayView: View {
    @Binding var showMap: Bool // Referencia al estado externo que controla la visibilidad

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 11.0195, longitude: -74.8504),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Botón para cerrar el mapa y volver a la cámara
            Button(action: {
                showMap = false
            }) {
                Text("📷 Cámara")
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
        }
    }
}
