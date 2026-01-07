import SwiftUI

struct ItemBrowserView: View {
  @EnvironmentObject var loader: DataPackLoader
  @EnvironmentObject var userData: UserDataStore

  @State private var searchText = ""
  @State private var sortOption: SortOption = .name
  @State private var filterRarity: String? = nil
  @State private var showFavoritesOnly = false

  // Grid Layout
  let columns = [
    GridItem(.adaptive(minimum: 160), spacing: 16)
  ]

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
      ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(filteredItems) { item in
            ItemCard(item: item)
          }
        }
        .padding()
      }
      .background(Color(UIColor.systemGroupedBackground))
      .searchable(text: $searchText, prompt: "Search Items")
      .navigationTitle("Catalog")
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
          ContentUnavailableView("Loading Catalog...", systemImage: "arrow.triangle.2.circlepath")
        } else if filteredItems.isEmpty {
          ContentUnavailableView.search(text: searchText)
        }
      }
    }
  }
}

struct ItemCard: View {
  let item: CompactItem
  @State private var isExpanded = false
  @EnvironmentObject var userData: UserDataStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Header
      HStack(alignment: .top) {
        VStack(alignment: .leading) {
          Text(item.name)
            .font(.headline)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

          if let cat = item.category {
            Text(cat)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()

        Button {
          userData.toggleFavorite(itemId: item.id)
        } label: {
          Image(systemName: userData.isFavorite(itemId: item.id) ? "star.fill" : "star")
            .foregroundStyle(.yellow)
            .font(.caption)
        }
      }

      // Badge
      if let rarity = item.rarity {
        Text(rarity)
          .font(.caption2)
          .fontWeight(.semibold)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(4)
      }

      if isExpanded {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          if let val = item.value {
            Label("\(Int(val))", systemImage: "dollarsign.circle")
          }
          if let w = item.weight {
            Label(String(format: "%.1f kg", w), systemImage: "scalemass")
          }
          if let tier = item.tier {
            Label(tier, systemImage: "hammer")
          }

          NavigationLink(destination: ItemDetailView(item: item)) {
            Text("View Details")
              .font(.caption)
              .fontWeight(.bold)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(6)
          }
          .padding(.top, 4)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    .onTapGesture {
      withAnimation(.snappy) {
        isExpanded.toggle()
      }
    }
  }
}
