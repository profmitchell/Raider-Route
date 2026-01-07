import SwiftUI

struct MapView: View {
  var body: some View {
    NavigationStack {
      VStack {
        ContentUnavailableView(
          "Map Overlay",
          systemImage: "map",
          description: Text("Import a map image and calibrate it.")
        )
      }
      .navigationTitle("Map")
    }
  }
}
