import SwiftUI

struct PlannerView: View {
  var body: some View {
    NavigationStack {
      VStack {
        ContentUnavailableView(
          "Route Planner",
          systemImage: "map.circle",
          description: Text("Select a map and targets to generate a route.")
        )
      }
      .navigationTitle("Planner")
    }
  }
}
