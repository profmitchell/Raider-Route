import Foundation
import Combine

class UserDataStore: ObservableObject {
  @Published var favorites: Set<String> = []
  @Published var itemNotes: [String: String] = [:]

  private let favoritesFile = "favorites.json"
  private let notesFile = "item_notes.json"

  init() {
    loadData()
  }

  // MARK: - API

  func toggleFavorite(itemId: String) {
    if favorites.contains(itemId) {
      favorites.remove(itemId)
    } else {
      favorites.insert(itemId)
    }
    saveFavorites()
  }

  func isFavorite(itemId: String) -> Bool {
    return favorites.contains(itemId)
  }

  func getNote(itemId: String) -> String {
    return itemNotes[itemId] ?? ""
  }

  func saveNote(itemId: String, note: String) {
    if note.isEmpty {
      itemNotes.removeValue(forKey: itemId)
    } else {
      itemNotes[itemId] = note
    }
    saveNotes()
  }

  // MARK: - Persistence

  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  private func loadData() {
    // Favorites
    let favUrl = getDocumentsDirectory().appendingPathComponent(favoritesFile)
    if let data = try? Data(contentsOf: favUrl),
      let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
    {
      favorites = decoded
    }

    // Notes
    let notesUrl = getDocumentsDirectory().appendingPathComponent(notesFile)
    if let data = try? Data(contentsOf: notesUrl),
      let decoded = try? JSONDecoder().decode([String: String].self, from: data)
    {
      itemNotes = decoded
    }
  }

  private func saveFavorites() {
    let url = getDocumentsDirectory().appendingPathComponent(favoritesFile)
    if let data = try? JSONEncoder().encode(favorites) {
      try? data.write(to: url)
    }
  }

  private func saveNotes() {
    let url = getDocumentsDirectory().appendingPathComponent(notesFile)
    if let data = try? JSONEncoder().encode(itemNotes) {
      try? data.write(to: url)
    }
  }
}
