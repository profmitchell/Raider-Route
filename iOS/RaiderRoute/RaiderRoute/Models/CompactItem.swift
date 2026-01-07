import Foundation

struct CompactItem: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let category: String?
  let rarity: String?  // e.g. "Common", "Rare"
  let description: String?
  let value: Double?
  let weight: Double?
  let tier: String?  // e.g. "Tier 1"
  let tags: [String]?

  // Computed helper for sorting/filtering
  var rarityRank: Int {
    switch rarity?.lowercased() {
    case "common": return 1
    case "uncommon": return 2
    case "rare": return 3
    case "epic": return 4
    case "legendary": return 5
    default: return 0
    }
  }
}
