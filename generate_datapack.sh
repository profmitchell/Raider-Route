#!/bin/bash
set -euo pipefail

# --- From PREreq1.md ---

BASE="https://metaforge.app"
OUT="./DataPack"
RAW="$OUT/raw"
DER="$OUT/derived"

mkdir -p "$RAW" "$DER"

POLITE_SLEEP="0.35"
LIMIT="100"

# Helpers
fetch() {
  local url="$1"
  local out="$2"

  echo "GET $url"
  curl -sS \
    --fail \
    --retry 3 \
    --retry-all-errors \
    --connect-timeout 15 \
    --max-time 60 \
    -H "Accept: application/json" \
    "$url" > "$out"

  sleep "$POLITE_SLEEP"
}

# Items
echo "=== Downloading ITEMS ==="
page=1
all_items_tmp="$RAW/items._merge.tmp.jsonl"
rm -f "$all_items_tmp"

while true; do
  url="$BASE/api/arc-raiders/items?page=$page&limit=$LIMIT&includeComponents=true&sortBy=name&sortOrder=asc"
  out="$RAW/items.page.$page.json"
  fetch "$url" "$out"

  count=$(jq -r '
    if type=="object" and has("data") and (.data|type)=="array" then (.data|length)
    elif type=="array" then length
    else 0 end
  ' "$out")

  echo "  items page $page count=$count"

  jq -c '
    if type=="object" and has("data") and (.data|type)=="array" then .data[]
    elif type=="array" then .[]
    else empty end
  ' "$out" >> "$all_items_tmp"

  if [ "$count" -lt "$LIMIT" ]; then
    break
  fi
  page=$((page+1))
done

jq -s '.' "$all_items_tmp" > "$RAW/items.all.json"
rm -f "$all_items_tmp"
echo "Wrote $RAW/items.all.json"

# Arcs
echo "=== Downloading ARCS ==="
page=1
all_arcs_tmp="$RAW/arcs._merge.tmp.jsonl"
rm -f "$all_arcs_tmp"

while true; do
  url="$BASE/api/arc-raiders/arcs?page=$page&limit=$LIMIT&includeLoot=true&sortBy=name&sortOrder=asc"
  out="$RAW/arcs.page.$page.json"
  fetch "$url" "$out"

  count=$(jq -r '
    if type=="object" and has("data") and (.data|type)=="array" then (.data|length)
    elif type=="array" then length
    else 0 end
  ' "$out")

  echo "  arcs page $page count=$count"

  jq -c '
    if type=="object" and has("data") and (.data|type)=="array" then .data[]
    elif type=="array" then .[]
    else empty end
  ' "$out" >> "$all_arcs_tmp"

  if [ "$count" -lt "$LIMIT" ]; then
    break
  fi
  page=$((page+1))
done

jq -s '.' "$all_arcs_tmp" > "$RAW/arcs.all.json"
rm -f "$all_arcs_tmp"
echo "Wrote $RAW/arcs.all.json"

# Maps
echo "=== Downloading MAP DATA ==="
MAP_IDS=( "dam" "spaceport" "buried-city" "blue-gate" "stella-montis" )

for mapID in "${MAP_IDS[@]}"; do
  url="$BASE/api/game-map-data?tableID=arc_map_data&mapID=$mapID"
  out="$RAW/map.$mapID.json"
  echo "  mapID=$mapID"
  if curl -sS --fail --retry 3 --retry-all-errors -H "Accept: application/json" "$url" > "$out"; then
    echo "    wrote $out"
  else
    echo "    FAILED for mapID=$mapID (keeping going)"
    rm -f "$out"
  fi
  sleep "$POLITE_SLEEP"
done

# Manifest
python3 - <<'PY'
import json, os, time
raw = "./DataPack/raw"
manifest = {
  "schemaVersion": 1,
  "createdISO": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "files": sorted([f for f in os.listdir(raw) if f.endswith(".json")]),
}
os.makedirs("./DataPack", exist_ok=True)
with open("./DataPack/manifest.raw.json", "w") as f:
  json.dump(manifest, f, indent=2)
print("Wrote ./DataPack/manifest.raw.json")
PY


# --- From PREREQ2.md ---
echo "=== Building DERIVED Indexes ==="

python3 - <<'PY'
import json, os, math, re
from pathlib import Path

BASE = Path("./DataPack")
RAW = BASE/"raw"
DER = BASE/"derived"
DER.mkdir(parents=True, exist_ok=True)

def load_json(p):
  with open(p, "r") as f: return json.load(f)

def write_json(p, obj):
  p.parent.mkdir(parents=True, exist_ok=True)
  with open(p, "w") as f: json.dump(obj, f, indent=2)

def norm(s: str) -> str:
  s = s.lower().strip()
  s = re.sub(r"[^a-z0-9\s]", " ", s)
  s = re.sub(r"\s+", " ", s).strip()
  return s

# Items
try:
    items = load_json(RAW/"items.all.json")
    item_index = {}
    for it in items:
      name = it.get("name") or it.get("displayName") or it.get("title") or ""
      iid = it.get("id") or it.get("_id") or it.get("itemID") or ""
      if not name or not iid: continue
      item_index[norm(name)] = {"id": iid, "name": name}

    roman_to_digit = {" i":" 1"," ii":" 2"," iii":" 3"}
    digit_to_roman = {" 1":" i"," 2":" ii"," 3":" iii"}
    for k, v in list(item_index.items()):
      for r,d in roman_to_digit.items():
        if k.endswith(r):
          item_index[k[:-len(r)] + d] = v
      for d,r in digit_to_roman.items():
        if k.endswith(d):
          item_index[k[:-len(d)] + r] = v

    write_json(DER/"item_index.json", item_index)

    # Components
    components_index = {}
    for it in items:
      iid = it.get("id") or it.get("_id") or it.get("itemID")
      if not iid: continue
      comps = []
      raw_comps = it.get("components") or it.get("craftingComponents") or []
      if isinstance(raw_comps, list):
        for c in raw_comps:
          if not isinstance(c, dict): continue
          cid = c.get("id") or c.get("itemId") or c.get("itemID") or c.get("componentId")
          qty = c.get("quantity") or c.get("qty") or 1
          if cid:
            comps.append({"componentId": cid, "qty": int(qty)})
      if comps:
        components_index[iid] = comps

    write_json(DER/"item_components_index.json", components_index)
except Exception as e:
    print(f"Warning processing items: {e}")


# Arcs
try:
    arcs = load_json(RAW/"arcs.all.json")
    arc_index = {}
    arc_loot_index = {}

    for a in arcs:
      aid = a.get("id") or a.get("_id") or a.get("arcID")
      name = a.get("name") or a.get("displayName") or a.get("title") or ""
      if aid and name:
        arc_index[norm(name)] = {"id": aid, "name": name}

      loot = a.get("loot") or a.get("drops") or a.get("items") or a.get("rewards") or []
      if isinstance(loot, list):
        for li in loot:
          if isinstance(li, dict):
            item_id = li.get("itemId") or li.get("id") or li.get("itemID")
          else:
            item_id = None
          if item_id and aid:
            arc_loot_index.setdefault(item_id, [])
            if aid not in arc_loot_index[item_id]:
              arc_loot_index[item_id].append(aid)

    write_json(DER/"arc_index.json", arc_index)
    write_json(DER/"arc_loot_index.json", arc_loot_index)
except Exception as e:
    print(f"Warning processing arcs: {e}")

# Maps
def extract_nodes(map_json):
  if isinstance(map_json, dict):
    if "allData" in map_json and isinstance(map_json["allData"], list):
      return map_json["allData"]
    if "data" in map_json and isinstance(map_json["data"], list):
      return map_json["data"]
  if isinstance(map_json, list):
    return map_json
  return []

def dist(a,b):
  return math.sqrt((a["lat"]-b["lat"])**2 + (a["lng"]-b["lng"])**2)

RAW_MAPS = [p for p in RAW.glob("map.*.json")]
for p in RAW_MAPS:
  try:
      map_id = p.name.split("map.",1)[1].rsplit(".json",1)[0]
      mj = load_json(p)
      nodes = extract_nodes(mj)

      compact = []
      for n in nodes:
        if not isinstance(n, dict): continue
        try:
          lat = float(n.get("lat"))
          lng = float(n.get("lng"))
        except Exception:
          continue
        compact.append({
          "id": n.get("id"),
          "mapID": n.get("mapID") or map_id,
          "lat": lat,
          "lng": lng,
          "category": n.get("category"),
          "subcategory": n.get("subcategory"),
          "instanceName": n.get("instanceName"),
        })

      write_json(DER/f"map.{map_id}.nodes.compact.json", compact)

      spawns = [c for c in compact if c.get("subcategory") == "player_spawn"]
      containers = [c for c in compact if c.get("category") == "containers"]
      arc_nodes = [c for c in compact if c.get("category") == "arc"]

      write_json(DER/f"map.{map_id}.spawns.json", spawns)
      write_json(DER/f"map.{map_id}.containers.json", containers)
      write_json(DER/f"map.{map_id}.arcs.json", arc_nodes)

      # Graph
      graph_nodes = spawns + containers + arc_nodes
      seen = set()
      uniq_nodes = []
      for n in graph_nodes:
        nid = n.get("id")
        if nid and nid not in seen:
          seen.add(nid)
          uniq_nodes.append(n)

      K = 6
      edges = []
      for i, n in enumerate(uniq_nodes):
        dists = []
        for j, m in enumerate(uniq_nodes):
          if i == j: continue
          dists.append((dist(n,m), m["id"]))
        dists.sort(key=lambda x: x[0])
        for w, to_id in dists[:K]:
          edges.append({"fromId": n["id"], "toId": to_id, "weight": w})

      write_json(DER/f"map.{map_id}.graph.json", {"nodes": uniq_nodes, "edges": edges})
  except Exception as e:
      print(f"Error processing map {p.name}: {e}")

# Manifest
manifest = {
  "schemaVersion": 1,
  "rawFiles": sorted([f.name for f in RAW.glob("*.json")]),
  "derivedFiles": sorted([f.name for f in DER.glob("*.json")]),
}
write_json(BASE/"manifest.derived.json", manifest)
print("Wrote derived indexes + graphs.")
PY
