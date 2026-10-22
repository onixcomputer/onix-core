#!/usr/bin/env bash
# build_all.sh — wait for the downloads, finish the slim release tree, build the
# spliced TP3 pack and verify it. Runs ON the head (spark-e442) while the old
# deployment is still serving, so it (a) keeps dirty pages bounded with a sync
# loop, (b) aborts if MemFree gets low (the GB10 driver allocates from MemFree),
# and (c) resumes per shard on a re-run.
set -uo pipefail
R=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw
OUT=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-TP3
PY=$HOME/.venvs/hf/bin/python
LOG=$R/logs/build.log
exec > >(tee -a "$LOG") 2>&1

banner() { echo "=== $* $(date -Is) ==="; }

( while :; do sync; sleep 5; done ) &
SYNCER=$!

# watchdog: stop the build if MemFree drops below 1.5 GiB (resumable per shard)
[ -n "${BUILD_PID:-}" ] || true
watchdog() {
  while :; do
    free_gib=$(awk '/MemFree/{printf "%d", $2/1048576}' /proc/meminfo)
    if [ "$free_gib" -lt 2 ] && [ -n "${BUILD_PID:-}" ] && kill -0 "$BUILD_PID" 2>/dev/null; then
      echo "!!! MemFree ${free_gib} GiB, killing build $BUILD_PID"
      kill "$BUILD_PID"
      break
    fi
    sleep 10
  done
}

banner "waiting for downloads"
for i in $(seq 1 720); do
  body=$(ls "$R/body"/model-*.safetensors 2>/dev/null | wc -l)
  eng=$(ls "$R/engram"/model-*.safetensors 2>/dev/null | wc -l)
  slim=$(ls "$R/slim"/model-*.safetensors 2>/dev/null | wc -l)
  [ "$body" -ge 43 ] && [ "$eng" -ge 2 ] && [ "$slim" -ge 46 ] && break
  echo "  body=$body/43 engram=$eng/2 slim=$slim/46 ($(date +%H:%M:%S))"
  sleep 60
done
[ "$body" -ge 43 ] || { echo "ABORT: pack body incomplete ($body/43)"; exit 1; }
[ "$eng" -ge 2 ] || { echo "ABORT: engram incomplete ($eng/2)"; exit 1; }
[ "$slim" -ge 46 ] || { echo "ABORT: slim release incomplete ($slim/46)"; exit 1; }
grep -q FINISHED-SLIM "$R/logs/slim.log" || { echo "ABORT: slim fetch did not finish"; exit 1; }

banner "finalize slim tree"
$PY $HOME/dsv41-1017/finalize_slim.py \
    --release-index "$R/release/model.safetensors.index.json" \
    --slim "$R/slim" --engram-dir "$R/engram" || exit 1

banner "build spliced TP3 pack -> $OUT"
mkdir -p "$OUT"
$PY -c "
import hashlib, sys
d = hashlib.sha256(open('$R/release/model.safetensors.index.json','rb').read()).hexdigest()
print('release index sha256', d[:16])
" 
BUILD_PID=""
$PY $HOME/dsv41-1017/build_tp3_pack.py \
    --release "$R/slim" --pack "$R/body" --out "$OUT" --verify &
BUILD_PID=$!
watchdog &
WD=$!
wait $BUILD_PID
rc=$?
kill $WD 2>/dev/null
[ $rc -eq 0 ] || { echo "ABORT: build failed rc=$rc"; exit $rc; }

banner "pack ready"
du -sh "$OUT"; ls "$OUT" | head -20
kill $SYNCER 2>/dev/null
echo "BUILD-ALL-DONE $(date -Is)"
