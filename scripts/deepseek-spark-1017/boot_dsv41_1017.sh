#!/usr/bin/env bash
# Boot orchestrator for the 1017 TP3 deployment (worker-first: rank2 -> rank1 -> rank0/head).
# Runs ON the head (spark-e442). Mirrors boot_dsv41_ours.sh, defaults set to the
# configuration the previous (V4.1 3.5bpw ablit) deployment was serving.
set -e
J="ssh -n -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new -i $HOME/.ssh/dspark-cluster"
R1="${R1:-dspark-worker}"                 # spark-a0a0
R2="${R2:-brittonr@192.168.1.233}"        # spark-6d1b

: "${IMAGE:=vllm-dsv41:exl3a}"
: "${EXP_NAME:=dsv41-1017a}"
: "${MODEL_DIR:=DeepSeek-V4.1-Flash-1017-EXL3-TP3}"
: "${GMU:=0.80}"
: "${MAXLEN:=300000}"
: "${SEQS:=8}"
: "${MAX_BATCHED:=4096}"
: "${EAGER:=0}"
: "${CUDAGRAPH_MODE:=FULL_AND_PIECEWISE}"
: "${SPEC:=dspark}"
: "${SPEC_K:=5}"
: "${ENGRAM_DISK:=1}"
: "${ENGRAM_THREADS:=32}"
: "${ENGRAM_CHUNK:=16}"
: "${TEXT_ONLY:=0}"
: "${THINKING:=false}"
: "${PARSERS:=1}"
: "${RUST_FE:=0}"
: "${VLLM_EXTRA:---block-size 128 --limit-mm-per-prompt {\"image\":4} --mm-processor-cache-gb 1 --mm-encoder-tp-mode data}"

KNOBS=""
for k in EXP_NAME GMU MAXLEN SEQS MAX_BATCHED EAGER CUDAGRAPH_MODE SPEC SPEC_K IMAGE MODEL_DIR \
         ENGRAM_DISK ENGRAM_THREADS ENGRAM_CHUNK ENGRAM_LOCAL PATCH_NAME TEXT_ONLY THINKING \
         PARSERS RUST_FE VLLM_EXTRA NCCL_EXTRA; do
  v="${!k:-}"; [ -n "$v" ] && KNOBS="$KNOBS $k='$v'"
done
echo "knobs:$KNOBS"

run() {
  if [ "$1" = "local" ]; then
    bash -c "export $KNOBS; bash $HOME/dsv41-tp3-1017.sh $2"
  else
    $J "$1" "export $KNOBS; bash ~/dsv41-tp3-1017.sh $2"
  fi
}

# Flush page cache (userspace, no root): posix_fadvise DONTNEED over the pack,
# run inside the serving image so the workers need no host python.
flush() {
  local who="$1" d="/var/tmp/models/$MODEL_DIR"
  # $HOME is expanded here: the head and both workers use the same home path.
  local cmd="docker run --rm -v $d:/mnt:ro -v $HOME/dsv41-1017/flush_cache.py:/flush.py:ro --entrypoint python3 $IMAGE /flush.py /mnt"
  if [ "$who" = local ]; then bash -c "$cmd"; else $J "$who" "$cmd"; fi
}
echo "== flush page cache on all three nodes =="
flush "$R2"; flush "$R1"; flush local

echo "== rank 2 ($R2) =="; run "$R2" 2
echo "== rank 1 ($R1) =="; run "$R1" 1
sleep 5
echo "== rank 0 (head) =="; run local 0
echo "all three launched $(date)"
