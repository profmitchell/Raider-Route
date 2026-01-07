DOCUMENT 1 — PRD (Raider Route iOS, Bundled DataPack Only)

Product name: Raider Route
Platform: iOS (offline-only runtime)
AI: Apple Foundation Models only (no external LLMs in V1)
Networking: NONE in the iOS app (no URLSession, no API calls)
Data updates: done on Mac via Cursor terminal scripts; JSON is bundled into the app as resources

1) Summary
Raider Route is a personal iOS app that plans routes in ARC Raiders using a locally bundled dataset (“DataPack”). The app never downloads data from the internet. Instead, you generate/refresh the DataPack on your Mac (items, arcs, map nodes + derived indexes/graphs) and include it in the Xcode project as compiled resources. The app uses deterministic routing over prebuilt graphs and optionally uses Apple Foundation Models to interpret natural-language requests and generate grounded explanations.

2) V1 Goals
- 100% offline runtime
- Load bundled JSON DataPack resources at launch (or lazily)
- Search items and arcs instantly using derived indexes
- Map setup wizard:
  - select map
  - import map image
  - calibrate 3–4 anchors
  - confirm overlay
- Map overlay:
  - show spawns/containers/arcs/locations toggles
  - show labels optionally
  - show route polyline
- Planner:
  - choose map + spawn + targets (items/components/arcs)
  - choose style: safe / balanced / fast / loot-heavy
  - generate primary route + 1–2 variants
- Raid feedback:
  - Start Raid / End Raid
  - rating 1–5 + optional tags + note
  - learn per-map node/edge penalties/bonuses to personalize routes
- Apple Foundation Models:
  - parse user intent (“spawned at ___ want ___ safer”)
  - generate explanation grounded in local facts
- “Basic mode” fallback if Foundation Models unavailable:
  - deterministic parsing + template output

3) V1 Non-goals
- No network requests or live API access
- No event timers
- No traders (optional later if bundled)
- No scraping
- No real-time tracking
- No true navmesh/pathfinding through geometry; routing is POI graph-based
- No public distribution requirements

4) DataPack (Bundled Resources) — Required Files
The app bundle must contain:

A) Raw (optional to ship, useful for debugging)
- DataPack/raw/items.all.json
- DataPack/raw/arcs.all.json
- DataPack/raw/map.<mapID>.json (optional if derived exists)

B) Derived (required for performance + simplicity)
- DataPack/derived/item_index.json
- DataPack/derived/item_components_index.json
- DataPack/derived/arc_index.json
- DataPack/derived/arc_loot_index.json
- DataPack/derived/map.<mapID>.nodes.compact.json
- DataPack/derived/map.<mapID>.spawns.json
- DataPack/derived/map.<mapID>.containers.json
- DataPack/derived/map.<mapID>.arcs.json
- DataPack/derived/map.<mapID>.graph.json
- DataPack/manifest.derived.json

Maps supported (V1)
- dam
- spaceport
- buried-city
- blue-gate
- stella-montis (if present in DataPack)

5) On-device Persistent Storage (User Data Only)
Application Support (or Documents) stores ONLY user-generated data:
- calibrations/
  - map.<mapID>.calibration.json (affine transform + chosen anchors + image reference)
- raidHistory/
  - sessions.json
  - learned_profile.<mapID>.json
- userMaps/
  - imported map images (copied into app storage so they persist)

6) Core Capabilities

6.1 Search (offline)
- Items:
  - resolve by name via item_index.json
  - show item detail using raw items (if shipped) OR a compact item cache built at first launch
  - optional: show crafting components chain using item_components_index.json
- Arcs:
  - resolve by name via arc_index.json
  - show arcs that drop an item using arc_loot_index.json

6.2 Map overlay (offline)
- Load compact nodes for selected map
- Display:
  - spawns, containers, arcs toggles
  - optional labels
- After calibration exists, transform dataset coords (lat,lng) -> image pixels and draw accurately

6.3 Routing (offline)
- Use prebuilt graph (map.<mapID>.graph.json)
- Shortest path engine (Dijkstra)
- Multi-target plan:
  - simple heuristic: nearest-next + shortest paths between
- Style weights applied to edge/node cost using learned_profile + style presets

6.4 Calibration (offline)
- User imports map image
- User picks 3–4 anchor nodes from list and taps their locations on image
- Compute affine transform:
  x = a*lat + b*lng + tx
  y = c*lat + d*lng + ty
- Preview overlay; user confirms
- Save transform and image reference

6.5 Learning (offline)
- Start Raid captures current plan + timestamp
- End Raid captures rating/tags/note
- Update LearnedProfile:
  - adjust node bonuses/penalties
  - optionally adjust global style preferences per map

7) Apple Foundation Models integration
- Only used for:
  - intent extraction (map/spawn/targets/style)
  - grounded explanation formatting (route steps, why)
- The model must not invent facts:
  - all facts come from local data lookups
- Fallback:
  - deterministic parse + template explanation

8) UX
Tabs:
1) DataPack
- shows DataPack version (manifest)
- shows included maps
- shows counts
- shows “DataPack loaded” status
2) Planner
- map picker
- spawn picker
- target picker (items/arcs)
- style
- generate route
- Start/End Raid controls
3) Map
- calibration wizard
- overlay toggles
- route preview
4) Search
- items/arcs search
5) History
- sessions list
- learned profile summary

9) Acceptance Criteria
- App runs in Airplane Mode with full functionality
- Loads DataPack and can search items/arcs instantly
- Calibration produces correct overlay alignment
- Route generation works and draws on map image
- Raid feedback modifies future route selection
- No networking code exists in the app target