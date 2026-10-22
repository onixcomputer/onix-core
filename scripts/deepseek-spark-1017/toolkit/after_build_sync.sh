#!/usr/bin/env bash
# Wait for the pack build, then replicate it to both workers (resumable).
set -uo pipefail
R=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw
for i in $(seq 1 240); do
  grep -qE "BUILD-ALL-DONE" $R/logs/build.log && break
  grep -qE "ABORT" $R/logs/build.log && { echo "build aborted, not syncing"; exit 1; }
  sleep 30
done
grep -qE "BUILD-ALL-DONE" $R/logs/build.log || { echo "timeout waiting for build"; exit 1; }
KEEP=both BW=200m bash ~/dsv41-1017/sync_to_workers.sh
echo "AFTER-BUILD-SYNC-DONE $(date -Is)"
