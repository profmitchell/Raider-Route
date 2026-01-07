import SwiftUI

struct ItemDetailView: View {
  let item: CompactItem
  @EnvironmentObject var loader: DataPackLoader
  @EnvironmentObject var userData: UserDataStore
  @State private var userNote: String = ""

  var components: [ComponentEntry] {
    loader.itemComponentsIndex[item.id] ?? []
  }

  var droppingArcs: [ArcIndexEntry] {
    guard let arcIds = loader.arcLootIndex[item.id] else { return [] }
    return arcIds.compactMap { loader.arcIndex[$0] }
  }

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            if let rarity = item.rarity {
              Text(rarity.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .padding(4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            }
            if let tier = item.tier {
              Text(tier)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }

          if let desc = item.description {
            Text(desc)
              .font(.body)
          }

          HStack {
            if let val = item.value {
              Label("\(Int(val))", systemImage: "dollarsign.circle")
            }
            if let w = item.weight {
              Label(String(format: "%.1f kg", w), systemImage: "scalemass")
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }

      if !components.isEmpty {
        Section("Crafting Components") {
          ForEach(components, id: \.componentId) { comp in
            if let compItem = resolveItem(id: comp.componentId) {
              NavigationLink(destination: ItemDetailView(item: compItem)) {
                HStack {
                  Text(compItem.name)
                  Spacer()
                  Text("x\(comp.qty)")
                    .foregroundStyle(.secondary)
                }
              }
            } else {
              HStack {
                Text(comp.componentId)  // Fallback
                Spacer()
                Text("x\(comp.qty)")
              }
            }
          }
        }
      }

      if !droppingArcs.isEmpty {
        Section("Dropped By Arcs") {
          ForEach(droppingArcs, id: \.id) { arc in
            NavigationLink(destination: ArcDetailView(arc: arc)) {
              Text(arc.name)
            }
          }
        }
      }

      Section("Notes") {
        TextEditor(text: $userNote)
          .frame(minHeight: 100)
          .onChange(of: userNote) {
            userData.saveNote(itemId: item.id, note: userNote)
          }
      }
    }
    .navigationTitle(item.name)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          userData.toggleFavorite(itemId: item.id)
        } label: {
          Image(systemName: userData.isFavorite(itemId: item.id) ? "star.fill" : "star")
            .foregroundStyle(.yellow)
        }
      }
    }
    .onAppear {
      userNote = userData.getNote(itemId: item.id)
    }
  }

  private func resolveItem(id: String) -> CompactItem? {
    // Find in compact list (slow for large lists, map optimization could be added later)
    return loader.compactItems.first { $0.id == id }
  }
}
