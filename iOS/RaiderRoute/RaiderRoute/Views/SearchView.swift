import SwiftUI

struct SearchView: View {
  @EnvironmentObject var loader: DataPackLoader
  @State private var query = ""

  var body: some View {
    NavigationStack {
      List {
        if query.isEmpty {
          ContentUnavailableView.search
        } else {
          // Placeholder results
          Text("Searching for '\(query)' in DataPack...")
        }
      }
      .searchable(text: $query, prompt: "Search Items & Arcs")
      .navigationTitle("Search")
    }
  }
}
