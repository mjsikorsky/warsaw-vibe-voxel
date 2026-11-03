#!/bin/sh
# Full data pipeline: download (cached) -> mosaic -> voxelize -> web/public/data.
# Everything the viewer loads that depends on OSM, the LiDAR or the tiles is rebuilt here, so no file is left from an
# older OSM next to fresh tiles. Not rebuilt (fixed inputs, not OSM): climate.json (climate.py), windows.json
# (window_stats.py), data/raw/notable.json (notable.py).
set -e
cd "$(dirname "$0")/.."
py() { PYTHONPATH=scripts uv run python "scripts/$1.py"; }
sh scripts/fetch_osm.sh
sh scripts/fetch_gugik.sh
py fetch_trees      # Warsaw's tree databases (cached per tile), read by voxelize via trees.py
py wikidata         # names and sitelinks for the OSM features that link to Wikidata (cached), for places.py
py prep
py voxelize         # tiles, meta.json, trees.json, data/ground.npz
py terrain          # terrain.bin, from data/ground.npz
py places
py flood
py windows          # windows.bin: building kinds from OSM
py phenology        # phenology.json, foliage.bin: from trees.json
# zones.bin: building and block ids (the mesher never merges faces across buildings) and, from data/cost1m.json, each
# block's triangles, which bound how much a phone loads. Without that table zones.json has no costs and phones would
# load every block, so stop here rather than write it.
if [ ! -s data/cost1m.json ]; then
  echo "data/cost1m.json missing: with 'pnpm dev' running in web/, run 'node web/tools/cost1m.mjs data/cost1m.json'," >&2
  echo "then 'PYTHONPATH=scripts uv run python scripts/zones.py' (zones.bin is out of date until then)" >&2
  exit 1
fi
py zones
