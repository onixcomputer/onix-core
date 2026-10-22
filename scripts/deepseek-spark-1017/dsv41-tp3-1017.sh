#!/usr/bin/env bash
# dsv41-tp3-1017.sh — DeepSeek-V4.1-Flash-1017 EXL3 TP3 launcher (3× GB10).
#
# Same contract as dsv41-tp3b-ours.sh (Tech2Wild/Kai), with the 1017 pack as the
# default model. Rank map:
#   0 head   spark-e442 192.168.1.244   (API :8888)
#   1 worker spark-a0a0 192.168.1.234   (--headless)
#   2 worker spark-6d1b 192.168.1.233   (--headless)
# Model: /var/tmp/models/$MODEL_DIR on every node (local copies, no NFS).
#
# Differences from dsv41-tp3b-ours.sh:
#   * MODEL_DIR defaults to the spliced 1017 TP3 pack
#   * EXP_NAME defaults to dsv41-1017a (fresh vLLM cache dir)
#   * --restart unless-stopped (matches the container this replaces)
#   * no `sudo tee /proc/sys/vm/drop_caches` (no passwordless sudo on these
#     hosts); flush_cache.py (posix_fadvise DONTNEED) does the same job from
#     userspace before boot.
set -euo pipefail
NODE_RANK="${1:?usage: dsv41-tp3-1017.sh <0|1|2>}"

IMAGE="${IMAGE:-vllm-dsv41:exl3a}"
EXP_NAME="${EXP_NAME:-dsv41-1017a}"
GMU="${GMU:-0.80}"
MAXLEN="${MAXLEN:-300000}"
SEQS="${SEQS:-8}"
MAX_BATCHED="${MAX_BATCHED:-4096}"
EAGER="${EAGER:-0}"
CUDAGRAPH_MODE="${CUDAGRAPH_MODE:-FULL_AND_PIECEWISE}"
CG_SIZES="${CG_SIZES:-}"
SPEC="${SPEC:-dspark}"
ENGRAM_DISK="${ENGRAM_DISK:-1}"
TEXT_ONLY="${TEXT_ONLY:-0}"
THINKING="${THINKING:-false}"
PARSERS="${PARSERS:-1}"
RUST_FE="${RUST_FE:-0}"
VLLM_EXTRA="${VLLM_EXTRA:-}"
NCCL_EXTRA="${NCCL_EXTRA:-}"

NAME="vllm_dsv41"
MODEL_DIR="${MODEL_DIR:-DeepSeek-V4.1-Flash-1017-EXL3-TP3}"
CACHE_HOST_PATH="/var/tmp/dsv41-vllm-cache"
TOK_ARGS=""
case "$IMAGE" in *deepseekv41-flash-0909*) TOK_ARGS="--tokenizer-mode deepseek_v41" ;; esac
SITE="/usr/local/lib/python3.12/dist-packages/vllm"
HEAD_IP="192.168.1.244"; MPORT="29541"; PORT="8888"

case "$NODE_RANK" in
  0) HOST_IP=192.168.1.244; HEADLESS="";           MODEL_HOST="/var/tmp/models/$MODEL_DIR"; TP_IF=enP7s7 ;;
  1) HOST_IP=192.168.1.234; HEADLESS="--headless"; MODEL_HOST="/var/tmp/models/$MODEL_DIR"; TP_IF=enP7s7 ;;
  2) HOST_IP=192.168.1.233; HEADLESS="--headless"; MODEL_HOST="/var/tmp/models/$MODEL_DIR"; TP_IF=enP7s7 ;;
  *) echo "rank must be 0-2" >&2; exit 2 ;;
esac

# ---- preflight ----
test -f "$MODEL_HOST/config.json" || { echo "MODEL MISSING at $MODEL_HOST" >&2; exit 3; }
test -f "$MODEL_HOST/model-00048-of-00048.safetensors" || { echo "MODEL INCOMPLETE at $MODEL_HOST (shard 48 missing)" >&2; exit 3; }
PATCH_DIR="${PATCH_DIR:-$HOME/patches/${PATCH_NAME:-dsv41-exl3-tp3e}}"
PATCH_MOUNTS=""
if [ -f "$PATCH_DIR/mounts.txt" ]; then
  while read -r f rel; do
    [ -z "$f" ] && continue
    if [ "$ENGRAM_DISK" != "1" ] && { [ "$f" = "engram.py" ] || [ "$f" = "weight_utils.py" ] || [ "$f" = "model_state.py" ]; }; then continue; fi
    test -f "$PATCH_DIR/$f" || { echo "PATCH FILE MISSING: $PATCH_DIR/$f" >&2; exit 3; }
    case "$rel" in /*) tgt="$rel" ;; *) tgt="$SITE/$rel" ;; esac; PATCH_MOUNTS="$PATCH_MOUNTS -v $PATCH_DIR/$f:$tgt:ro"
  done < "$PATCH_DIR/mounts.txt"
else
  echo "no mounts.txt in $PATCH_DIR" >&2; exit 3
fi
if [ "$ENGRAM_DISK" = "1" ]; then
  ENGRAM_ENV="-e DSV41_ENGRAM_DISK=1 -e DSV41_ENGRAM_DISK_THREADS=${ENGRAM_THREADS:-32} -e DSV41_ENGRAM_DISK_CHUNK=${ENGRAM_CHUNK:-16}"
else
  ENGRAM_ENV="-e DSV41_ENGRAM_DISK=0"
fi
ENGRAM_LOCAL_HOST="${ENGRAM_LOCAL_HOST:-/var/tmp/engram-local/$MODEL_DIR}"
ENGRAM_LOCAL_MOUNT=""
if [ "$ENGRAM_DISK" = "1" ] && [ "${ENGRAM_LOCAL:-0}" = "1" ] && [ -f "$ENGRAM_LOCAL_HOST/engram-local.json" ]; then
  ENGRAM_LOCAL_MOUNT="-v $ENGRAM_LOCAL_HOST:/engram-local:ro"
  ENGRAM_ENV="$ENGRAM_ENV -e DSV41_ENGRAM_DIR=/engram-local"
fi
mkdir -p "$CACHE_HOST_PATH"
docker rm -f "$NAME" 2>/dev/null || true
sync
AVAIL_GB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1048576 ))
FREE_GB=$(( $(grep MemFree /proc/meminfo | awk '{print $2}') / 1048576 ))
[ "$AVAIL_GB" -ge 100 ] || { echo "MemAvailable ${AVAIL_GB} GiB < 100 GiB, refusing to boot" >&2; exit 4; }

GRAPH_ENV=""
GRAPH_ARGS=()
if [ "$EAGER" = "1" ]; then
  GRAPH_ARGS=(--enforce-eager)
else
  if [ "$ENGRAM_DISK" = "1" ] && ! grep -q '^model_state.py ' "$PATCH_DIR/mounts.txt"; then
    echo "EAGER=0 + ENGRAM_DISK=1 needs the Engram prestage patch (model_state.py in mounts.txt)" >&2; exit 3
  fi
  if [ -z "$CG_SIZES" ]; then
    if [ "$SPEC" = "dspark" ]; then
      K="${SPEC_K:-5}"
      CG_SIZES=$( { seq "$K" "$K" $((K * SEQS)); seq $((K + 1)) $((K + 1)) $(((K + 1) * SEQS)); } | sort -n -u | paste -sd, - )
    else
      CG_SIZES=$(seq 1 "$SEQS" | paste -sd, -)
    fi
  fi
  GRAPH_ARGS=(--compilation-config "{\"cudagraph_mode\":\"$CUDAGRAPH_MODE\",\"cudagraph_capture_sizes\":[$CG_SIZES]}")
  GRAPH_ENV="-e VLLM_USE_BREAKABLE_CUDAGRAPH=1"
fi
if [ "$EAGER" = "1" ]; then SPEC_ADAPT=false; else SPEC_ADAPT="${SPEC_ADAPT:-false}"; fi
if [ "$SPEC" = "dspark" ]; then
  SPEC_ARGS="--speculative-config {\"method\":\"dspark\",\"num_speculative_tokens\":${SPEC_K:-5},\"draft_sample_method\":\"probabilistic\",\"rejection_sample_method\":\"block\",\"enable_adaptive_verification\":${SPEC_ADAPT}}"
else SPEC_ARGS=""; fi
if [ "$TEXT_ONLY" = "1" ]; then TEXT_ARGS="--language-model-only"; else TEXT_ARGS=""; fi
if [ "$PARSERS" = "1" ]; then PARSER_ARGS="--tool-call-parser deepseek_v41 --enable-auto-tool-choice --reasoning-parser deepseek_v41"; else PARSER_ARGS=""; fi

# shellcheck disable=SC2086
docker run --gpus all -d --name "$NAME" --restart unless-stopped \
  --network host --ipc host --shm-size 32g --memory 112g --memory-swap 112g \
  --ulimit memlock=-1:-1 --cap-add IPC_LOCK --device /dev/infiniband:/dev/infiniband \
  --oom-score-adj 500 \
  -v "$MODEL_HOST:/models/$MODEL_DIR:ro" \
  -v "$CACHE_HOST_PATH:/cache" \
  $PATCH_MOUNTS $ENGRAM_LOCAL_MOUNT \
  -e VLLM_HOST_IP=$HOST_IP -e HF_HOME=/cache/huggingface -e HF_HUB_OFFLINE=1 -e TRANSFORMERS_OFFLINE=1 \
  -e VLLM_CACHE_ROOT="/cache/vllm-$EXP_NAME" \
  -e VLLM_ENGINE_READY_TIMEOUT_S=3600 -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6 \
  -e CUDA_EXL3_MODEL_PATH=/models/$MODEL_DIR -e VLLM_USE_RUST_FRONTEND=$RUST_FE -e VLLM_HAS_FLASHINFER_CUBIN=1 \
  $ENGRAM_ENV $GRAPH_ENV \
  -e TORCH_CUDA_ARCH_LIST=12.1a -e FLASHINFER_CUDA_ARCH_LIST=12.1a -e FLASHINFER_DISABLE_VERSION_CHECK=1 \
  -e NCCL_NET=Socket -e NCCL_IB_DISABLE=1 -e NCCL_SOCKET_IFNAME=enP7s7 \
  -e GLOO_SOCKET_IFNAME=$TP_IF -e TP_SOCKET_IFNAME=$TP_IF -e MN_IF_NAME=$TP_IF \
  -e NCCL_NVLS_ENABLE=0 -e NCCL_CROSS_NIC=0 -e NCCL_IB_MERGE_NICS=0 -e NCCL_CUMEM_ENABLE=0 \
  -e NCCL_IGNORE_CPU_AFFINITY=1 -e NCCL_DEBUG=WARN -e TORCH_NCCL_ASYNC_ERROR_HANDLING=1 \
  $NCCL_EXTRA \
  "$IMAGE" \
    "/models/$MODEL_DIR" \
    --served-model-name deepseek-v4.1-flash --host 0.0.0.0 --port "$PORT" \
    $TOK_ARGS \
    --tensor-parallel-size 3 --gpu-memory-utilization "$GMU" --max-model-len "$MAXLEN" \
    --max-num-seqs "$SEQS" --max-num-batched-tokens "$MAX_BATCHED" \
    --engram-config '{"cpu_offload": false}' \
    --default-chat-template-kwargs "{\"thinking\": $THINKING}" \
    $TEXT_ARGS $PARSER_ARGS $SPEC_ARGS "${GRAPH_ARGS[@]}" \
    --distributed-executor-backend mp --nnodes 3 --node-rank "$NODE_RANK" \
    --master-addr "$HEAD_IP" --master-port "$MPORT" $HEADLESS $VLLM_EXTRA

echo "launched $NAME rank=$NODE_RANK exp=$EXP_NAME image=$IMAGE patches=$PATCH_DIR gmu=$GMU maxlen=$MAXLEN seqs=$SEQS eager=$EAGER cg=${CUDAGRAPH_MODE}[${CG_SIZES}] spec=$SPEC adapt=$SPEC_ADAPT engram_disk=$ENGRAM_DISK engram_local=${ENGRAM_LOCAL_MOUNT:+yes} text_only=$TEXT_ONLY avail=${AVAIL_GB}GiB free=${FREE_GB}GiB"
sleep 3
docker ps --format '{{.Names}} {{.Status}}' | grep "$NAME" || { echo "$NAME exited" >&2; docker logs --tail 40 "$NAME" >&2; exit 1; }
