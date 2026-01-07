import Foundation

struct CompactMapNode: Identifiable, Decodable {
  let id: String
  let mapID: String?
  let lat: Double
  let lng: Double
  let category: String?
  let subcategory: String?
  let instanceName: String?

  // For UI
  var displayText: String {
    return instanceName ?? subcategory ?? category ?? "Unknown"
  }
}
