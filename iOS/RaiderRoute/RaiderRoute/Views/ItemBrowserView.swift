import SwiftUI

struct ItemBrowserView: View {
  @EnvironmentObject var loader: DataPackLoader
  @EnvironmentObject var userData: UserDataStore

  @State private var searchText = ""
  @State private var sortOption: SortOption = .name
  @State private var filterRarity: String? = nil
  @State private var showFavoritesOnly = false

  enum SortOption {
    case name, rarity, value
  }

  var filteredItems: [CompactItem] {
    var items = loader.compactItems

    // Filter by Search
    if !searchText.isEmpty {
      items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // Filter by Rarity
    if let rarity = filterRarity {
      items = items.filter { $0.rarity?.lowercased() == rarity.lowercased() }
    }

    // Filter Favorites
    if showFavoritesOnly {
      items = items.filter { userData.isFavorite(itemId: $0.id) }
    }

    // Sort
    return items.sorted { a, b in
      switch sortOption {
      case .name:
        return a.name < b.name
      case .rarity:
        return a.rarityRank > b.rarityRank  // High rarity first
      case .value:
        return (a.value ?? 0) > (b.value ?? 0)
      }
    }
  }

  var body: some View {
    NavigationStack {
      List(filteredItems) { item in
        NavigationLink(destination: ItemDetailView(item: item)) {
          ItemRow(item: item)
        }
      }
      .searchable(text: $searchText, prompt: "Search Items")
      .navigationTitle("Items")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker("Sort", selection: $sortOption) {
              Text("Name").tag(SortOption.name)
              Text("Rarity").tag(SortOption.rarity)
              Text("Value").tag(SortOption.value)
            }

            Toggle("Favorites Only", isOn: $showFavoritesOnly)

            Menu("Rarity") {
              Button("All") { filterRarity = nil }
              Button("Common") { filterRarity = "Common" }
              Button("Uncommon") { filterRarity = "Uncommon" }
              Button("Rare") { filterRarity = "Rare" }
              Button("Epic") { filterRarity = "Epic" }
              Button("Legendary") { filterRarity = "Legendary" }
            }
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .overlay {
        if loader.compactItems.isEmpty {
          ContentUnavailableView("Loading Items...", systemImage: "arrow.triangle.2.circlepath")
        } else if filteredItems.isEmpty {
          ContentUnavailableView.search(text: searchText)
        }
      }
    }
  }
}

struct ItemRow: View {
  let item: CompactItem

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(item.name)
          .font(.headline)
        if let cat = item.category {
          Text(cat)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      if let rarity = item.rarity {
        Text(rarity)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.gray.opacity(0.2))
          .cornerRadius(4)
      }
    }
  }
}
