#!/usr/bin/env bash
# sync_to_workers.sh — replicate the 1017 TP3 pack to spark-a0a0 (CX7) and spark-6d1b (LAN).
# Runs on the head (spark-e442). Resumable (--append-verify): re-run after an interruption.
# bwlimit keeps the receiver/sender dirty-page window small while the OLD deployment is
# still serving on all three nodes (GB10 driver allocates from MemFree, not MemAvailable).
set -euo pipefail
SRC="${SRC:-/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-TP3}"
DEST="${DEST:-/var/tmp/models/$(basename "$SRC")}"
BW="${BW:-200m}"
KEEP="${KEEP:-a0a0}"
SSH="ssh -T -o BatchMode=yes -o ConnectTimeout=20 -i $HOME/.ssh/dspark-cluster -c aes128-gcm@openssh.com"

( while :; do sync; sleep 5; done ) &
SYNCER=$!
trap 'kill $SYNCER 2>/dev/null || true' EXIT

run() {  # run <ssh-target> <label>
  local target="$1" label="$2"
  echo "== $label ($target) =="
  $SSH "$target" "mkdir -p '$DEST'"
  rsync -a --info=progress2 --partial --append-verify --bwlimit="$BW" --no-compress \
        -e "$SSH" "$SRC/" "$target:$DEST/"
  $SSH "$target" "ls -la '$DEST' | head -5; du -sh '$DEST'; df -h /var/tmp | tail -1"
  echo "== $label done $(date -Is) =="
}

[ "$KEEP" = "both" ] || KEEP_ONE=1
run dspark-worker "a0a0 (CX7 10.44.0.2)"
[ "${KEEP}" = "both" ] && run brittonr@192.168.1.233 "6d1b (LAN)"
sync
echo "all targets synced $(date -Is)"
