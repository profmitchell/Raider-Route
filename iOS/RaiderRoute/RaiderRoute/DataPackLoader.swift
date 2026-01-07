import Combine
import Foundation

struct MissingFile: Identifiable {
  let id = UUID()
  let filename: String
}

class DataPackLoader: ObservableObject {
  @Published var isLoaded = false
  @Published var missingFiles: [MissingFile] = []
  @Published var manifest: Manifest?

  // In-memory caches
  var itemIndex: [String: ItemIndexEntry] = [:]
  var itemComponentsIndex: [String: [ComponentEntry]] = [:]
  var arcIndex: [String: ArcIndexEntry] = [:]
  var arcLootIndex: [String: [String]] = [:]

  // Compact Items Cache
  @Published var compactItems: [CompactItem] = []

  // Helper for bundle path
  private var bundle: Bundle { Bundle.main }

  func load() {
    // Run on background to avoid blocking UI
    DispatchQueue.global(qos: .userInitiated).async {
      let missing = self.validateRequiredFiles()

      DispatchQueue.main.async {
        self.missingFiles = missing
        if missing.isEmpty {
          self.loadIndexes()
          self.loadCompactItems()
          self.isLoaded = true
        }
      }
    }
  }

  func validateRequiredFiles() -> [MissingFile] {
    let required = [
      "DataPack/derived/item_index.json",
      "DataPack/derived/item_components_index.json",
      "DataPack/derived/arc_index.json",
      "DataPack/derived/arc_loot_index.json",
      "DataPack/derived/manifest.derived.json",
    ]

    var missing: [MissingFile] = []
    for path in required {
      let filename = (path as NSString).lastPathComponent
      var found = false

      // Try 1: Exact path as subdirectory (Folder Reference)
      if bundle.url(forResource: filename, withExtension: nil, subdirectory: "DataPack/derived")
        != nil
      {
        found = true
      }
      // Try 2: Flat in root (Group)
      else if bundle.url(forResource: filename, withExtension: nil) != nil {
        found = true
      }
      // Try 3: Just "derived" subdirectory
      else if bundle.url(forResource: filename, withExtension: nil, subdirectory: "derived") != nil
      {
        found = true
      }

      if !found {
        missing.append(MissingFile(filename: path))
      }
    }
    return missing
  }

  private func loadCompactItems() {
    DispatchQueue.global(qos: .userInitiated).async {
      // Look for items.all.json to parse into compact items
      let locations: [String?] = ["DataPack/raw", "raw", "DataPack/derived", "derived", nil]
      var url: URL?
      for loc in locations {
        if let u = self.bundle.url(
          forResource: "items.all.json", withExtension: nil, subdirectory: loc)
        {
          url = u
          break
        }
      }

      guard let foundUrl = url else {
        print("DataPackLoader: items.all.json not found, skipping compact item cache.")
        return
      }

      do {
        let data = try Data(contentsOf: foundUrl)
        let rawItems = try JSONDecoder().decode([RawItemStub].self, from: data)

        let compact = rawItems.compactMap { item -> CompactItem? in
          // Prefer explicit ID fields
          guard let id = item.id ?? item._id ?? item.itemID else { return nil }
          let name = item.name ?? item.displayName ?? item.title ?? "Unknown"

          return CompactItem(
            id: id,
            name: name,
            category: item.category ?? item.type,
            rarity: item.rarity,
            description: item.description,
            value: item.value ?? item.price,
            weight: item.weight,
            tier: item.tier ?? item.workbench,
            tags: item.tags
          )
        }

        DispatchQueue.main.async {
          self.compactItems = compact
          print("DataPackLoader: Parsed \(compact.count) compact items.")
        }
      } catch {
        print("DataPackLoader: Failed to parse items.all.json: \(error)")
      }
    }
  }

  private func loadIndexes() {
    self.itemIndex = loadJSON(filename: "item_index.json") ?? [:]
    self.itemComponentsIndex = loadJSON(filename: "item_components_index.json") ?? [:]
    self.arcIndex = loadJSON(filename: "arc_index.json") ?? [:]
    self.arcLootIndex = loadJSON(filename: "arc_loot_index.json") ?? [:]
    self.manifest = loadJSON(filename: "manifest.derived.json")
  }

  private func loadJSON<T: Decodable>(filename: String) -> T? {
    // Try multiple locations
    let locations: [String?] = [
      "DataPack/derived",
      "derived",
      nil,  // Root
    ]

    var url: URL?
    for loc in locations {
      if let u = bundle.url(forResource: filename, withExtension: nil, subdirectory: loc) {
        url = u
        break
      }
    }

    guard let validUrl = url else {
      print("Could not find file: \(filename)")
      return nil
    }

    do {
      let data = try Data(contentsOf: validUrl)
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      print("Failed to decode \(filename): \(error)")
      return nil
    }
  }
}

// Structures matching the JSON schema
struct Manifest: Decodable {
  let schemaVersion: Int
  let derivedFiles: [String]
}

struct ItemIndexEntry: Decodable {
  let id: String
  let name: String
}

struct ComponentEntry: Decodable {
  let componentId: String
  let qty: Int
}

struct ArcIndexEntry: Decodable {
  let id: String
  let name: String
}

// Helper struct for parsing raw items
private struct RawItemStub: Decodable {
  let id: String?
  let _id: String?
  let itemID: String?
  let name: String?
  let displayName: String?
  let title: String?
  let category: String?
  let type: String?
  let rarity: String?
  let description: String?
  let value: Double?
  let price: Double?
  let weight: Double?
  let tier: String?
  let workbench: String?
  let tags: [String]?
}
