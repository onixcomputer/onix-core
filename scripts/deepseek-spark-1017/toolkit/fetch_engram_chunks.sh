#!/usr/bin/env bash
# fetch_engram_chunks.sh — fetch the two 101 GiB Engram shards with parallel
# byte-range requests, verify against the LFS sha256 from the Hub, and only then
# publish the final name. Resumable: complete part files are reused.
set -uo pipefail
R=/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw
REV=1bae0e1088993b9b82de08f59de5be5a34e42170
BASE="https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017/resolve/$REV"
PARTS=64
PARALLEL=24
LOG=$R/logs/engram-chunks.log
exec >>"$LOG" 2>&1
echo "=== chunked engram fetch $(date -Is) ==="

fetch_one() {
  local file="$1" size="$2" sha="$3"
  local dir="$R/engram/.parts/$file"
  local chunk=$(( (size + PARTS - 1) / PARTS ))
  mkdir -p "$dir"
  echo "-- $file: $size bytes in $PARTS parts of ~$((chunk/1048576)) MiB"
  seq 0 $((PARTS - 1)) | xargs -P "$PARALLEL" -I{} bash -c '
    i={}; file="$0"; size='"$size"'; chunk='"$chunk"'; dir="'"$dir"'"; base="'"$BASE"'"
    start=$((i * chunk)); end=$((start + chunk - 1)); [ "$end" -ge "$size" ] && end=$((size - 1))
    want=$((end - start + 1)); out="$dir/$i"
    if [ -f "$out" ] && [ "$(stat -c %s "$out")" -eq "$want" ]; then echo "  part $i cached"; exit 0; fi
    for try in 1 2 3 4 5; do
      curl -sfL --max-time 1800 --retry 0 -r "$start-$end" -o "$out.$$" "$base/$file" || { sleep 5; continue; }
      [ "$(stat -c %s "$out.$$")" -eq "$want" ] && { mv "$out.$$" "$out"; echo "  part $i ok"; exit 0; }
      sleep 5
    done
    echo "  part $i FAILED"; exit 1
  ' "$file"
  local rc=$?
  [ $rc -eq 0 ] || { echo "!! $file: part failures"; return 1; }

  local tmp="$R/engram/$file.assembling"
  cat $(seq 0 $((PARTS - 1)) | sed "s|^|$dir/|") > "$tmp"
  local got; got=$(stat -c %s "$tmp")
  [ "$got" -eq "$size" ] || { echo "!! $file: assembled $got != $size"; return 1; }
  echo -- "$file: verifying sha256 (takes a few minutes)"
  local have; have=$(sha256sum "$tmp" | cut -d" " -f1)
  if [ "$have" != "$sha" ]; then echo "!! $file: sha256 $have != $sha"; return 1; fi
  mv "$tmp" "$R/engram/$file"
  rm -rf "$dir"
  echo "OK $file ($size bytes, sha256 verified)"
}

fetch_one model-00047-of-00048.safetensors 101535150936 76a05106ece259be83d1bfea0dcb54f23377864ee60fd321690f35e6698a2af5 || exit 1
fetch_one model-00048-of-00048.safetensors 101537926640 9dc51433e195bc78b5ad846b68643cc0351d3b174e5e4309222d3b7402c83afd || exit 1
echo "FETCH-ENGRAM-CHUNKS-DONE $(date -Is)"
