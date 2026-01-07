DOCUMENT 3 — Cursor Prompt: Build Raider Route iOS (Bundled Resources Only)

You are Cursor. Build an iOS SwiftUI app named “Raider Route”.

Hard constraints
- ZERO networking in the iOS app (no URLSession, no API calls).
- All game data is loaded from bundled resources under a folder named “DataPack”.
- The DataPack is generated externally on macOS and included in the app bundle.
- Apple Foundation Models only for optional natural-language intent + explanation.
- Provide a “Basic mode” fallback if Foundation Models is unavailable.

DataPack file structure in Bundle
- DataPack/derived/item_index.json
- DataPack/derived/item_components_index.json
- DataPack/derived/arc_index.json
- DataPack/derived/arc_loot_index.json
- DataPack/derived/map.<mapID>.nodes.compact.json
- DataPack/derived/map.<mapID>.spawns.json
- DataPack/derived/map.<mapID>.containers.json
- DataPack/derived/map.<mapID>.arcs.json
- DataPack/derived/map.<mapID>.graph.json
- DataPack/derived/manifest.derived.json
Optional:
- DataPack/raw/items.all.json
- DataPack/raw/arcs.all.json

App responsibilities
- Load and validate DataPack on launch, show missing-file errors clearly.
- Provide offline search for items and arcs using the derived indexes.
- Provide per-map calibration:
  - import map image
  - choose 3–4 anchor nodes from the map’s compact nodes
  - tap anchor locations on image
  - compute affine transform and save to disk
  - preview overlay, confirm
- Provide routing:
  - load map.<mapID>.graph.json
  - Dijkstra shortest path
  - multi-target route: nearest-next + shortest path segments
  - styles: safe/balanced/fast/loot-heavy
  - incorporate learned preferences (penalties/bonuses)
- Provide raid history:
  - Start Raid / End Raid
  - rating/tags/note
  - update learned preferences per map

Deliverables
- Full project structure
- Swift files:
  - DataPackLoader.swift (Bundle reading + validation)
  - Models.swift (CompactMapNode, Graph, indexes)
  - SearchEngine.swift
  - Router.swift (Dijkstra + variants)
  - Calibration.swift (affine transform)
  - UserStorage.swift (images, calibrations, history)
  - RaidHistory.swift + LearnedProfile.swift
  - FoundationAssistant.swift + fallback templates
  - SwiftUI views for DataPack/Planner/Map/Search/History
- Ensure it compiles and runs with a provided DataPack folder in the bundle.

DOCUMENT 4 — Cursor Prompt: DataPackLoader.swift (Bundle Resource Loading)

Implement DataPackLoader.swift to load JSON files from the app Bundle.

Requirements
- No networking.
- Provide:
  - validateRequiredFiles() -> [MissingFile]
  - loadItemIndex() -> [String: ItemIndexEntry]
  - loadItemComponentsIndex() -> [String: [ComponentEntry]]
  - loadArcIndex() -> [String: ArcIndexEntry]
  - loadArcLootIndex() -> [String: [String]]
  - loadMapNodes(mapID) -> [CompactMapNode]
  - loadMapGraph(mapID) -> Graph
  - loadManifest() -> Manifest

Implementation notes
- Support DataPack bundled either:
  A) directly in main Bundle resources, or
  B) as Swift Package resources via Bundle.module (optional)
- Use JSONDecoder
- Cache loaded content in-memory so screens are fast
- Provide clear error messages for missing or corrupt files




DOCUMENT 5 — Cursor Prompt: Router.swift (Graph Search Offline)

Implement Router.swift using only local graph JSON.

Inputs
- mapID
- Graph { nodes[], edges[] }
- startNodeId
- targetNodeIds[]
- style: safe/balanced/fast/lootHeavy
- LearnedProfile (optional)

Behavior
- Run Dijkstra on a directed graph edge list.
- Edge base weight = edge.weight (Euclidean distance already).
- Add style modifiers:
  - safe increases penalty for nodes/edges marked risky in LearnedProfile
  - lootHeavy decreases cost for nodes with positive bonus
  - fast emphasizes distance only
- Multi-target plan:
  - order targets by nearest-next from current position
  - compute shortest path segments between targets
- Output:
  - primary route waypoint IDs
  - 1–2 variants by changing weights or excluding top-penalty node
  - summary: distance estimate, waypoint count, key reasons
- Do not attempt navmesh or obstacle avoidance (V1).




DOCUMENT 6 — Cursor Prompt: Calibration.swift (Affine Transform + Overlay)

Implement Calibration.swift.

Goal
- Transform dataset coordinates (lat,lng) to image pixels (x,y) using an affine transform.

Transform
- Store as:
  a,b,c,d,tx,ty
- Apply:
  x = a*lat + b*lng + tx
  y = c*lat + d*lng + ty

Compute
- Given 3 or more anchor pairs:
  (lat,lng) <-> (x,y)
- Solve least squares for affine transform.

UI integration
- Provide a function to generate overlay points:
  - map nodes -> [CGPoint] in image pixel space
- Provide a validation method:
  - compute average alignment error across anchors

Persistence
- Save calibration JSON per map in Application Support/calibrations/
- Include:
  - mapID
  - imageFilename
  - anchorPairs (nodeId + lat/lng + x/y)
  - transform matrix
  - createdAt



DOCUMENT 7 — Cursor Prompt: UserStorage.swift (Images + Calibrations + History)

Implement UserStorage.swift.

Requirements
- Store user-imported map images in Application Support/userMaps/
- Store calibration files in Application Support/calibrations/
- Store raid sessions in Application Support/raidHistory/sessions.json
- Store learned profiles in Application Support/raidHistory/learned_profile.<mapID>.json

Provide helpers:
- saveImportedImage(uiImage)->filename
- loadImage(filename)->UIImage?
- saveCalibration(mapID, calibration)
- loadCalibration(mapID)->Calibration?
- appendRaidSession(session)
- loadRaidSessions()->[RaidSession]
- saveLearnedProfile(mapID, profile)
- loadLearnedProfile(mapID)->LearnedProfile?

DOCUMENT 8 — Cursor Prompt: RaidHistory + Learning (No Neural Training)

Implement:
- RaidSession.swift
- RaidHistoryStore.swift
- LearnedProfile.swift
- LearningEngine.swift

RaidSession fields
- id, mapID, spawnNodeId, plannedWaypoints[]
- startedAt, endedAt
- rating (1..5)
- tags [String] (optional chips)
- note String (optional)

LearnedProfile
- nodeBonus[nodeId]: Double
- nodePenalty[nodeId]: Double
- edgePenalty["a|b"]: Double
- preferredStyleWeights (optional per map)

Learning rules (simple)
- rating >= 4: add small bonus to nodes in plannedWaypoints
- rating <= 2: add penalty to nodes in plannedWaypoints
- tag “too hot”: increase penalty for arc nodes used in route
- tag “too long”: increase global complexity penalty
- clamp bonuses/penalties within reasonable bounds

Expose:
- updateProfile(after session, using map nodes/categories)
- Router consumes profile to adjust costs

DOCUMENT 9 — Cursor Prompt: FoundationAssistant.swift (Optional, Grounded)

Implement FoundationAssistant.swift.

Use Apple Foundation Models ONLY to:
1) Interpret user query into structured intent:
- mapID (or ask user to choose if missing)
- spawn name / node
- target item or arc name
- style preference

2) Generate explanation text for the planned route:
- Steps list referencing node instanceName/category
- Why this route (based on style + learned profile)
- Alternate suggestions

Rules
- Never invent facts.
- Use only facts passed in from local lookups.
- If model unavailable, fallback to template explanation.

Interface
- interpret(text)->Intent
- explain(intent, route, facts)->String

DOCUMENT 10 — Cursor Prompt: SwiftUI Screens (Bundled DataPack UX)

Build SwiftUI tabs:

1) DataPackView
- validates required DataPack files
- shows manifest info (maps included, counts)
- shows “DataPack OK” or missing file list

2) PlannerView
- Map picker (from manifest maps)
- Spawn picker (from spawns json)
- Target picker:
  - item search (item_index)
  - arc search (arc_index)
  - option: include item components chain targets
- Style picker
- Generate route button
- Start Raid / End Raid flow (rating/tags/note)

3) MapView
- Map picker
- Import image button
- Calibration wizard
- Overlay toggles (spawns/containers/arcs/labels)
- Route preview overlay

4) SearchView
- Items/Arcs segmented search
- item detail:
  - components list (from item_components_index)
  - arcs that drop it (arc_loot_index)
- arc detail:
  - related loot if present (optional if raw shipped)

5) HistoryView
- sessions list
- per-map “learned summary” (top avoided nodes, top preferred nodes)

Must run fully offline.






