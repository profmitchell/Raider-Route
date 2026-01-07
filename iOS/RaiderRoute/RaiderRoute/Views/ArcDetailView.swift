import SwiftUI

struct ArcDetailView: View {
  let arc: ArcIndexEntry

  var body: some View {
    List {
      Section {
        LabeledContent("ID", value: arc.id)
      }

      // In a fuller implementation, we could reverse lookup what items this arc drops
      // using the arcLootIndex if we inverted it or parsed arcs.all.json
      Section {
        Text("Loot information would appear here if using full Arc dataset.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle(arc.name)
  }
}
