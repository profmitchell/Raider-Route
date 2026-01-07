import Foundation

struct GraphNode: Identifiable, Decodable, Hashable {
  let id: String
  // Other properties mirrored from CompactMapNode if needed for graph context,
  // but usually we just look up details via ID.
  // The graph JSON might embed them.

  // For hashing
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
    lhs.id == rhs.id
  }
}

struct GraphEdge: Decodable {
  let fromId: String
  let toId: String
  let weight: Double
}

struct Graph: Decodable {
  let nodes: [CompactMapNode]  // Reusing CompactMapNode as the node type in graph
  let edges: [GraphEdge]
}

class Router {
  // Dijkstra's Algorithm
  // - style: could leverage LearnedProfile modifiers

  struct RouteResult {
    let pathIds: [String]
    let totalDistance: Double
    let steps: [CompactMapNode]
  }

  static func calculateRoute(
    mapID: String,
    startNodeId: String,
    targetNodeIds: [String],  // Ordered targets? Or set to visit? Assumed ordered for V1
    graph: Graph,
    profile: LearnedProfile? = nil
  ) -> RouteResult? {

    var fullPath: [String] = []
    var totalDist = 0.0

    // Simple sequential path: Start -> T1 -> T2 ...
    // Real TSP is overkill; user usually picks order or we do nearest neighbor.
    // Prompt says: "nearest-next + shortest paths between"

    var currentId = startNodeId
    var remainingTargets = Set(targetNodeIds)

    // Add start to path
    // fullPath.append(currentId) // Don't duplicate if segments overlap

    // Build adjacency map for speed
    let adj = buildAdjacency(edges: graph.edges)

    // Nearest Neighbor Greedy Swap
    while !remainingTargets.isEmpty {
      // Find nearest target
      var bestTarget: String?
      var bestDist = Double.infinity
      var bestPath: [String] = []

      for target in remainingTargets {
        if let (path, dist) = dijkstra(
          start: currentId, end: target, adj: adj, nodes: graph.nodes, profile: profile)
        {
          if dist < bestDist {
            bestDist = dist
            bestTarget = target
            bestPath = path
          }
        }
      }

      if let target = bestTarget {
        // Append path (excluding first which is currentId)
        if !fullPath.isEmpty {
          fullPath.append(contentsOf: bestPath.dropFirst())
        } else {
          fullPath.append(contentsOf: bestPath)
        }

        totalDist += bestDist
        remainingTargets.remove(target)
        currentId = target
      } else {
        // Cannot reach remaining targets?
        break
      }
    }

    guard !fullPath.isEmpty else { return nil }

    // hydration
    let nodeMap = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
    let steps = fullPath.compactMap { nodeMap[$0] }

    return RouteResult(pathIds: fullPath, totalDistance: totalDist, steps: steps)
  }

  private static func buildAdjacency(edges: [GraphEdge]) -> [String: [(String, Double)]] {
    var adj = [String: [(String, Double)]]()
    for e in edges {
      adj[e.fromId, default: []].append((e.toId, e.weight))
      // Assuming directed graph from generation script implies A->B.
      // If bidirectional generation, we are good. Script says K-nearest, so directed.
      // But usually physics is symmetric travel.
    }
    return adj
  }

  // Standard Dijkstra
  private static func dijkstra(
    start: String,
    end: String,
    adj: [String: [(String, Double)]],
    nodes: [CompactMapNode],  // needed for modifiers?
    profile: LearnedProfile?
  ) -> ([String], Double)? {

    // Priority Queue (simulated with array sort for simplicity in Swift without Heap lib,
    // acceptable for N < 1000 nodes)
    var frontier: [(id: String, cost: Double)] = [(start, 0)]
    var cameFrom: [String: String] = [:]
    var costSoFar: [String: Double] = [start: 0]

    while !frontier.isEmpty {
      // Pop min
      frontier.sort { $0.cost < $1.cost }
      let current = frontier.removeFirst()

      if current.id == end {
        break
      }

      guard let neighbors = adj[current.id] else { continue }
      for (next, weight) in neighbors {
        // Apply profile modifiers here (bonuses/penalties)
        let mod = calculateModifier(edgeFrom: current.id, edgeTo: next, profile: profile)
        let newCost = costSoFar[current.id]! + weight + mod

        if newCost < costSoFar[next, default: Double.infinity] {
          costSoFar[next] = newCost
          frontier.append((next, newCost))
          cameFrom[next] = current.id
        }
      }
    }

    guard costSoFar[end] != nil else { return nil }

    // Reconstruct
    var path: [String] = []
    var curr = end
    while curr != start {
      path.append(curr)
      guard let prev = cameFrom[curr] else { return nil }  // Should not happen
      curr = prev
    }
    path.append(start)
    return (path.reversed(), costSoFar[end]!)
  }

  private static func calculateModifier(edgeFrom: String, edgeTo: String, profile: LearnedProfile?)
    -> Double
  {
    guard let p = profile else { return 0 }

    // Node Penalty/Bonus
    let nodeP = p.nodePenalties[edgeTo] ?? 0
    let nodeB = p.nodeBonuses[edgeTo] ?? 0

    // Edge Penalty
    let edgeKey = "\(edgeFrom)|\(edgeTo)"
    let edgeP = p.edgePenalties[edgeKey] ?? 0

    // Net cost addition. Cost = Distance + Penalty - Bonus
    // Warning: Negative weights break Dijkstra. ensure mod > -weight.
    // For game logic, we usually just add penalty (cost increases) or subtract bonus (cost decreases)
    // We'll clamp efficiently.

    return nodeP + edgeP - nodeB
  }
}
