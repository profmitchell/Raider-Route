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
