import Combine
import Foundation

// Mock wrapper for iOS 26 "LanguageModel" API
class FoundationAssistant: ObservableObject {
  @Published var isProcessing = false
  @Published var lastResponse: String = ""

  // Feature flags
  let useRealModel = false  // Set to true if iOS 26 SDK available

  func interpretIntent(_ text: String) async -> UserIntent {
    isProcessing = true
    defer { isProcessing = false }

    // Simulate latency
    try? await Task.sleep(nanoseconds: 500_000_000)

    let lower = text.lowercased()

    if lower.contains("route") || lower.contains("plan") || lower.contains("go to") {
      // naive extraction
      return .planRoute(raw: text)
    } else if lower.contains("search") || lower.contains("find") || lower.contains("where is") {
      return .searchItem(raw: text)
    } else if lower.contains("explain") {
      return .explain(raw: text)
    }

    return .unknown
  }

  func explainRoute(steps: [CompactMapNode]) async -> String {
    isProcessing = true
    defer { isProcessing = false }

    // In a real implementation with LanguageModel:
    // let prompt = "Explain this route naturally: \(steps)"
    // return await model.generate(prompt)

    // Mock fallback
    try? await Task.sleep(nanoseconds: 800_000_000)

    if steps.isEmpty { return "No route to explain." }

    let total = steps.count
    let start = steps.first?.displayText ?? "Start"
    let end = steps.last?.displayText ?? "End"

    return
      "Start at \(start). Follow the path through \(total - 2) waypoints. You will pass through several areas including \(steps.dropFirst().first?.category ?? "corridors"). Finally, navigate carefully to reach \(end)."
  }
}

enum UserIntent {
  case planRoute(raw: String)
  case searchItem(raw: String)
  case explain(raw: String)
  case unknown
}
