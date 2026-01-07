DOCUMENT 2 — README (Raider Route iOS, Bundled DataPack)

Raider Route — iOS Offline Route Planner (Bundled JSON DataPack)

Overview
Raider Route is a personal offline-first iOS app for planning ARC Raiders routes. The app contains no networking. All game data is bundled into the app as a “DataPack” folder generated on a Mac using terminal scripts.

What’s included
- Item search and component lookup
- Arc lookup and “arcs that drop this item”
- Per-map POI overlays (spawns, containers, arcs)
- Map image calibration (align your image to dataset coordinates)
- Route planning (graph-based, multiple styles)
- Start/End Raid feedback to personalize future routes
- Optional Apple Foundation Models for natural-language intent + explanations

No networking
- The iOS app does not call MetaForge or any web endpoint
- Updates happen by regenerating DataPack on Mac and rebuilding the app

DataPack requirements
The app bundle must include:
DataPack/derived/
- item_index.json
- item_components_index.json
- arc_index.json
- arc_loot_index.json
- map.<mapID>.nodes.compact.json
- map.<mapID>.spawns.json
- map.<mapID>.containers.json
- map.<mapID>.arcs.json
- map.<mapID>.graph.json
- manifest.derived.json

Optional (debug):
DataPack/raw/
- items.all.json
- arcs.all.json
- map.<mapID>.json

User data stored on device
- Imported map images
- Per-map calibration transforms
- Raid session history
- Learned route preferences

Update workflow (monthly)
1) Run Mac scripts to download + build derived files into ./DataPack
2) Replace the DataPack folder in the Xcode project
3) Rebuild and run on device

Troubleshooting
- If the app says “Missing DataPack files”:
  - Confirm DataPack is added to Copy Bundle Resources
  - Confirm filenames match exactly
- If overlay points appear offset:
  - Recalibrate using anchors far apart (not clustered)
  - Use 4 anchors for best affine fit