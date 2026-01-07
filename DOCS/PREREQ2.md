# DOCUMENT 2 — Terminal: Build DERIVED indexes + routing graphs (recommended)
# This makes the iOS app faster + simpler: it loads compact files instead of scanning huge JSON.

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

# -------- Items: index + components --------
items = load_json(RAW/"items.all.json")
item_index = {}   # normalizedName -> {id, name}
for it in items:
  name = it.get("name") or it.get("displayName") or it.get("title") or ""
  iid = it.get("id") or it.get("_id") or it.get("itemID") or ""
  if not name or not iid: 
    continue
  item_index[norm(name)] = {"id": iid, "name": name}

# Lightweight aliasing for roman numerals I/II/III <-> 1/2/3 (good enough for V1)
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

# Components index (best-effort: structure varies)
components_index = {}  # itemId -> list[{componentId, qty}]
for it in items:
  iid = it.get("id") or it.get("_id") or it.get("itemID")
  if not iid: 
    continue

  comps = []
  # Common possibilities:
  # it["components"] as array of { itemId, quantity } or similar
  raw_comps = it.get("components") or it.get("craftingComponents") or []
  if isinstance(raw_comps, list):
    for c in raw_comps:
      if not isinstance(c, dict): 
        continue
      cid = c.get("id") or c.get("itemId") or c.get("itemID") or c.get("componentId")
      qty = c.get("quantity") or c.get("qty") or 1
      if cid:
        comps.append({"componentId": cid, "qty": int(qty)})
  if comps:
    components_index[iid] = comps

write_json(DER/"item_components_index.json", components_index)

# -------- Arcs: arc index + arc loot inverted index --------
arcs = load_json(RAW/"arcs.all.json")
arc_index = {}    # normalizedName -> {id, name}
arc_loot_index = {}  # itemId -> [arcId]

for a in arcs:
  aid = a.get("id") or a.get("_id") or a.get("arcID")
  name = a.get("name") or a.get("displayName") or a.get("title") or ""
  if aid and name:
    arc_index[norm(name)] = {"id": aid, "name": name}

  # Loot shape varies. We do best-effort.
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

# -------- Maps: compact nodes + spawns/containers/arcs + KNN graph --------
def extract_nodes(map_json):
  # observed: may have key "allData" or "data" or be an array
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
  map_id = p.name.split("map.",1)[1].rsplit(".json",1)[0]
  mj = load_json(p)
  nodes = extract_nodes(mj)

  compact = []
  for n in nodes:
    if not isinstance(n, dict): 
      continue
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

  # Build KNN graph from (spawns + containers + arcs)
  graph_nodes = spawns + containers + arc_nodes
  # de-dup by id
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
    # find K nearest
    dists = []
    for j, m in enumerate(uniq_nodes):
      if i == j: 
        continue
      dists.append((dist(n,m), m["id"]))
    dists.sort(key=lambda x: x[0])
    for w, to_id in dists[:K]:
      if n.get("id") and to_id:
        edges.append({"fromId": n["id"], "toId": to_id, "weight": w})

  write_json(DER/f"map.{map_id}.graph.json", {"nodes": uniq_nodes, "edges": edges})

# -------- Derived manifest --------
manifest = {
  "schemaVersion": 1,
  "rawFiles": sorted([f.name for f in RAW.glob("*.json")]),
  "derivedFiles": sorted([f.name for f in DER.glob("*.json")]),
}
write_json(BASE/"manifest.derived.json", manifest)
print("Wrote derived indexes + graphs.")
PY