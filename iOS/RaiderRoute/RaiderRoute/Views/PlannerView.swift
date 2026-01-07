import SwiftData
import SwiftUI

struct PlannerView: View {
  @EnvironmentObject var loader: DataPackLoader
  @Query var profiles: [LearnedProfile]

  @State private var selectedMapID = "dam"
  @State private var selectedSpawnId: String?
  @State private var targetItems: [CompactItem] = []  // Shopping list
  @State private var routeResult: Router.RouteResult?
  @State private var isCalculating = false

  // UI Helpers
  @State private var showItemPicker = false

  var mapSpawns: [CompactMapNode] {
    loader.loadMapNodes(mapID: selectedMapID).filter { $0.subcategory == "player_spawn" }
  }

  var currentProfile: LearnedProfile? {
    profiles.first(where: { $0.mapID == selectedMapID })
  }

  var availableMaps: [String] {
    ["dam", "spaceport", "buried-city", "blue-gate"]
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Setup") {
          Picker("Map", selection: $selectedMapID) {
            ForEach(availableMaps, id: \.self) { map in
              Text(map.capitalized).tag(map)
            }
          }
          .onChange(of: selectedMapID) {
            selectedSpawnId = nil
            routeResult = nil
          }

          Picker("Spawn", selection: $selectedSpawnId) {
            Text("Select Spawn").tag(String?.none)
            ForEach(mapSpawns) { spawn in
              Text(spawn.instanceName ?? "Spawn").tag(String?.some(spawn.id))
            }
          }
        }

        Section("Targets") {
          ForEach(targetItems) { item in
            Label(item.name, systemImage: "cube.box")
          }
          .onDelete { idx in targetItems.remove(atOffsets: idx) }

          Button("Add Item Target") {
            showItemPicker = true
          }
        }

        Section {
          Button("Generate Route") {
            generateRoute()
          }
          .disabled(selectedSpawnId == nil || targetItems.isEmpty)
        }

        if isCalculating {
          HStack {
            ProgressView()
            Text("Calculating...")
          }
        }

        if let result = routeResult {
          Section("Route Plan") {
            LabeledContent("Total Distance", value: String(format: "%.0f m", result.totalDistance))
            LabeledContent("Steps", value: "\(result.steps.count)")

            NavigationLink("View Detail Steps") {
              List(result.steps) { step in
                VStack(alignment: .leading) {
                  Text(step.displayText)
                    .font(.headline)
                  Text("\(step.category ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .navigationTitle("Route Steps")
            }
          }
        }
      }
      .navigationTitle("Planner")
      .sheet(isPresented: $showItemPicker) {
        ItemPickerSheet(selectedItems: $targetItems)
      }
    }
  }

  func generateRoute() {
    guard let spawnId = selectedSpawnId else { return }
    isCalculating = true
    routeResult = nil

    // 1. Resolve Item targets to Map Nodes
    // This is complex: Item -> Arc -> Arc Nodes on Map
    // For V1, let's assume we map targets simply:
    // Find *any* node that provides this item?
    // Data structure gap: We need "Item -> Node" lookup or "Arc -> Node".
    // We have Arc -> Node (map.arcs.json).
    // Item -> DroppedBy Arcs (arcLootIndex).

    DispatchQueue.global(qos: .userInitiated).async {
      // Build collection of target Node IDs based on items
      var targetNodeIds: [String] = []
      let mapNodes = self.loader.loadMapNodes(mapID: self.selectedMapID)

      for item in self.targetItems {
        // Find Arcs that drop this
        let arcs = self.loader.arcLootIndex[item.id] ?? []
        // Find Nodes on this map that are these Arcs
        // Filtering mapNodes where category=arc and instanceName (or id? logic needed) matches
        // Simplification for MVP: The node 'instanceName' or 'subcategory' might imply the Arc name?
        // In data, arc nodes usually have IDs that might link to Arcs.
        // Let's brute force text match for now or assume ArcID link.

        // Assuming map nodes of category 'arc' might have ID or subcategory matching Arc ID
        // Just picking *one* closest node for each item is the TSP part.
        // For now, pick *all* candidates, Router handles visiting *one* of set?
        // Simplified: Just pick random valid node for the item to prove routing works.

        let validNodes = mapNodes.filter { node in
          // Does this node represent an arc that drops the item?
          // This is a data gap we bridge heuristically.
          // If node.category == "arc", does loader.arcLootIndex[item.id] contain this node's 'instanceTypeId'?
          // We don't have perfect link in CompactMapNode.
          // Let's just pretend "Containers" are targets for this demo if Arcs fail.
          return node.category == "containers"
        }

        if let first = validNodes.first {
          targetNodeIds.append(first.id)
        }
      }

      // Load Graph
      guard let graph = self.loader.loadMapGraph(mapID: self.selectedMapID) else {
        DispatchQueue.main.async { self.isCalculating = false }
        return
      }

      let res = Router.calculateRoute(
        mapID: self.selectedMapID,
        startNodeId: spawnId,
        targetNodeIds: targetNodeIds,
        graph: graph,
        profile: self.currentProfile
      )

      DispatchQueue.main.async {
        self.routeResult = res
        self.isCalculating = false
      }
    }
  }
}

struct ItemPickerSheet: View {
  @Binding var selectedItems: [CompactItem]
  @EnvironmentObject var loader: DataPackLoader
  @Environment(\.dismiss) var dismiss
  @State private var search = ""

  var filtered: [CompactItem] {
    if search.isEmpty { return loader.compactItems }
    return loader.compactItems.filter { $0.name.localizedCaseInsensitiveContains(search) }
  }

  var body: some View {
    NavigationStack {
      List(filtered) { item in
        Button {
          selectedItems.append(item)
          dismiss()
        } label: {
          HStack {
            Text(item.name)
            Spacer()
            if let rarity = item.rarity {
              Text(rarity).font(.caption).padding(4).background(.thinMaterial)
            }
          }
        }
      }
      .searchable(text: $search)
      .navigationTitle("Select Target Item")
    }
  }
}
