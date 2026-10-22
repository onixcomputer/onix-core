#!/usr/bin/env bash
# Wait for the pack build, then byte-verify every tensor of the pack against its source.
set -uo pipefail
R=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw
OUT=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-TP3
for i in $(seq 1 240); do
  grep -qE "BUILD-ALL-DONE" $R/logs/build.log && break
  grep -qE "ABORT" $R/logs/build.log && { echo "build aborted"; exit 1; }
  sleep 30
done
bash -c "while :; do sync; sleep 5; done" & SY=$!
~/.venvs/hf/bin/python -u ~/dsv41-1017/verify_pack_full.py \
    --pack "$OUT" --slim "$R/slim" --experts "$R/body" --engram "$R/engram"
rc=$?
kill $SY 2>/dev/null
echo "FULL-VERIFY-EXIT $rc $(date -Is)"
