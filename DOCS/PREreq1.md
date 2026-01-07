# DOCUMENT 1 — Terminal: Download ALL JSON into a local DataPack (no iOS networking)

# Prereqs:
# - macOS
# - jq installed (brew install jq)
# - python3 installed (default on macOS)
#
# Creates:
#   ./DataPack/raw/...
#   ./DataPack/derived/... (optional if you run Document 2)

set -euo pipefail

BASE="https://metaforge.app"
OUT="./DataPack"
RAW="$OUT/raw"
DER="$OUT/derived"

mkdir -p "$RAW" "$DER"

POLITE_SLEEP="0.35"   # seconds between requests
LIMIT="100"

# -------- Helpers --------
fetch() {
  # usage: fetch "<url>" "<outfile>"
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

# -------- Items (paged) --------
echo "=== Downloading ITEMS ==="
page=1
all_items_tmp="$RAW/items._merge.tmp.jsonl"
rm -f "$all_items_tmp"

while true; do
  url="$BASE/api/arc-raiders/items?page=$page&limit=$LIMIT&includeComponents=true&sortBy=name&sortOrder=asc"
  out="$RAW/items.page.$page.json"
  fetch "$url" "$out"

  # Try common response shapes:
  # 1) { "data": [ ... ] }
  # 2) [ ... ]
  count=$(jq -r '
    if type=="object" and has("data") and (.data|type)=="array" then (.data|length)
    elif type=="array" then length
    else 0 end
  ' "$out")

  echo "  items page $page count=$count"

  # Append page data to jsonl merge file
  jq -c '
    if type=="object" and has("data") and (.data|type)=="array" then .data[]
    elif type=="array" then .[]
    else empty end
  ' "$out" >> "$all_items_tmp"

  # Stop when we get fewer than LIMIT
  if [ "$count" -lt "$LIMIT" ]; then
    break
  fi

  page=$((page+1))
done

# Create items.all.json as an array
jq -s '.' "$all_items_tmp" > "$RAW/items.all.json"
rm -f "$all_items_tmp"
echo "Wrote $RAW/items.all.json"

# -------- Arcs (paged) --------
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

# -------- Maps (per mapID) --------
echo "=== Downloading MAP DATA ==="
MAP_IDS=( "dam" "spaceport" "buried-city" "blue-gate" "stella-montis" )

for mapID in "${MAP_IDS[@]}"; do
  url="$BASE/api/game-map-data?tableID=arc_map_data&mapID=$mapID"
  out="$RAW/map.$mapID.json"

  # If one mapID doesn't exist, don't kill the whole script
  echo "  mapID=$mapID"
  if curl -sS --fail --retry 3 --retry-all-errors -H "Accept: application/json" "$url" > "$out"; then
    echo "    wrote $out"
  else
    echo "    FAILED for mapID=$mapID (keeping going)"
    rm -f "$out"
  fi
  sleep "$POLITE_SLEEP"
done

# -------- Manifest (raw only) --------
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

echo "DONE. Next: run Document 2 if you want derived indexes/graphs prebuilt."