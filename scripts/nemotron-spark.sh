#!/usr/bin/env bash
# Copy to the stock-Ubuntu Spark; run as a user with Docker access.
# prepare is CPU-only. start needs the existing GPU workload stopped separately.
# Access from a workstation through an explicit SSH tunnel, never a public bind.
set -euo pipefail

readonly IMAGE='vllm/vllm-openai@sha256:fd33bec1578f312a01547cc6b9691a5154c3e8bcfb76d2b35acb657bfc4eee8f'
readonly MODEL='nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4'
readonly MODEL_REV='59b8721646c38111a242da18218859fb2b454322'
readonly DRAFT='nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4-LiLiCorr'
readonly DRAFT_REV='292bf1efc06ba39567da7351f2ad7a522afa3959'
readonly NAME='onix-nemotron35'
readonly OWNER_LABEL='org.onix.nemotron35.state'
readonly STATE="${XDG_DATA_HOME:-$HOME/.local/share}/onix-nemotron35"
readonly BASE_DIR="$STATE/snapshots/base-$MODEL_REV"
readonly DRAFT_DIR="$STATE/snapshots/draft-$DRAFT_REV"

fail() {
  printf 'nemotron-spark: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf 'Usage: %s {prepare|start|stop|status}\n' "$0"
  printf '%s\n' \
    '  prepare  Pull the pinned image and download exact public model revisions (CPU only).' \
    '  start    Serve prepared local weights at 127.0.0.1:8000; refuse existing containers/ports.' \
    '  stop     Stop and remove only the container created for this state directory.' \
    '  status   Show the actual named-container state (running does not mean API-ready).' \
    "State: $STATE" \
    'No command stops other workloads or changes GPU settings. No credentials are needed.'
}

container_id() {
  docker container ls --all --filter "name=^/$NAME\$" --format '{{.ID}}'
}

prepared() {
  local directory=$1 repository=$2 revision=$3
  [[ -s "$directory/config.json" && -f "$directory/.onix-prepared" ]] &&
    [[ $(<"$directory/.onix-prepared") == "$repository@$revision" ]]
}

download() {
  local repository=$1 revision=$2 directory=$3
  if prepared "$directory" "$repository" "$revision"; then
    printf 'Already prepared: %s@%s\n' "$repository" "$revision"
    return
  fi
  # No GPU runtime, host credentials, or home directory are exposed to hf.
  # A successful complete download, not directory existence, marks preparation.
  docker run --rm --pull never --runtime runc \
    --memory 4g --memory-swap 4g \
    --user "$(id -u):$(id -g)" \
    --env NVIDIA_VISIBLE_DEVICES=void --env CUDA_VISIBLE_DEVICES= \
    --env HOME=/cache/home --env HF_HOME=/cache/huggingface \
    --env HF_HUB_DISABLE_IMPLICIT_TOKEN=1 --env HF_HUB_DISABLE_TELEMETRY=1 \
    --env HF_XET_NUM_CONCURRENT_RANGE_GETS=2 \
    --mount "type=bind,src=$STATE/download-cache,dst=/cache" \
    --mount "type=bind,src=$directory,dst=/snapshot" \
    --entrypoint hf "$IMAGE" \
    download "$repository" --revision "$revision" --local-dir /snapshot --max-workers 2
  [[ -s "$directory/config.json" ]] || fail "download did not produce $directory/config.json"
  printf '%s@%s\n' "$repository" "$revision" >"$directory/.onix-prepared"
}

prepare() {
  mkdir -p -- "$BASE_DIR" "$DRAFT_DIR" "$STATE/download-cache/home" "$STATE/runtime-cache/home"
  docker pull "$IMAGE"
  download "$MODEL" "$MODEL_REV" "$BASE_DIR"
  download "$DRAFT" "$DRAFT_REV" "$DRAFT_DIR"
  printf 'Prepared pinned snapshots in %s\n' "$STATE/snapshots"
}

start() {
  local existing listeners key value _unit available_kib=0
  existing=$(container_id)
  [[ -z $existing ]] || fail "container $NAME already exists ($existing); inspect it or use stop first"
  prepared "$BASE_DIR" "$MODEL" "$MODEL_REV" || fail 'base weights are not prepared; run prepare'
  prepared "$DRAFT_DIR" "$DRAFT" "$DRAFT_REV" || fail 'draft weights are not prepared; run prepare'
  [[ -d "$STATE/runtime-cache/home" ]] || fail 'runtime cache is missing; run prepare'
  docker image inspect "$IMAGE" >/dev/null
  command -v ss >/dev/null || fail 'ss (iproute2) is required to check port 8000'
  listeners=$(ss -H -ltn 'sport = :8000')
  [[ -z $listeners ]] || fail 'TCP port 8000 is already listening; refusing to interfere'
  while read -r key value _unit; do
    if [[ $key == MemAvailable: ]]; then
      available_kib=$value
      break
    fi
  done </proc/meminfo
  ((available_kib >= 100 * 1024 * 1024)) ||
    fail "need at least 100 GiB MemAvailable; found $available_kib KiB (stop existing workloads separately)"

  # Equal memory and memory-swap limits prohibit additional container swap.
  # All model assets are local and read-only; only dedicated caches are writable.
  docker run --detach --pull never --name "$NAME" \
    --label "$OWNER_LABEL=$STATE" \
    --network host --gpus all --ipc host \
    --memory 112g --memory-swap 112g --restart no \
    --user "$(id -u):$(id -g)" \
    --env HOME=/cache/home --env XDG_CACHE_HOME=/cache \
    --env HF_HOME=/cache/huggingface --env HF_HUB_OFFLINE=1 \
    --env TRANSFORMERS_OFFLINE=1 --env HF_HUB_DISABLE_IMPLICIT_TOKEN=1 \
    --env HF_HUB_DISABLE_TELEMETRY=1 --env VLLM_NO_USAGE_STATS=1 \
    --env VLLM_CACHE_ROOT=/cache/vllm --env TORCH_HOME=/cache/torch \
    --env TORCHINDUCTOR_CACHE_DIR=/cache/torchinductor \
    --env TRITON_CACHE_DIR=/cache/triton --env CUDA_CACHE_PATH=/cache/cuda \
    --mount "type=bind,src=$BASE_DIR,dst=/models/base,readonly" \
    --mount "type=bind,src=$DRAFT_DIR,dst=/models/draft,readonly" \
    --mount "type=bind,src=$STATE/runtime-cache,dst=/cache" \
    --entrypoint vllm "$IMAGE" serve /models/base \
    --host 127.0.0.1 --port 8000 \
    --served-model-name nemotron-3.5-super-vl \
    --max-model-len 65536 --max-num-seqs 1 \
    --gpu-memory-utilization 0.75 --max-num-batched-tokens 8192 \
    --language-model-only --trust-remote-code \
    --speculative-config '{"model":"/models/draft","num_speculative_tokens":7,"method":"dflash"}' \
    --mamba-backend flashinfer --mamba-ssm-cache-dtype float16 \
    --enable-mamba-cache-stochastic-rounding --mamba-cache-philox-rounds 5 \
    --enable-mamba-shared-prefix-checkpoint \
    --block-size 64 --prefix-match-unit 64 \
    --enable-auto-tool-choice --tool-call-parser qwen3_coder \
    --reasoning-parser nemotron_v3
  printf 'Container launched; model loading/compilation is not yet API readiness.\n'
  printf 'Logs: docker logs --follow %s\n' "$NAME"
  printf 'Readiness: curl --fail http://127.0.0.1:8000/v1/models\n'
}

stop() {
  local existing owner
  existing=$(container_id)
  if [[ -z $existing ]]; then
    printf '%s is absent; nothing to stop.\n' "$NAME"
    return
  fi
  owner=$(docker inspect --format "{{index .Config.Labels \"$OWNER_LABEL\"}}" "$existing")
  [[ $owner == "$STATE" ]] || fail "refusing to stop $NAME: it is not owned by this state directory"
  # Address the inspected ID, never a name that another process might replace.
  docker stop --timeout 60 "$existing"
  docker rm "$existing"
}

status() {
  local existing
  existing=$(container_id)
  if [[ -z $existing ]]; then
    printf '%s: absent\n' "$NAME"
    return
  fi
  docker inspect --format \
    "name={{.Name}} id={{.Id}} state={{.State.Status}} running={{.State.Running}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{json .State.Error}} owner={{index .Config.Labels \"$OWNER_LABEL\"}}" \
    "$existing"
  printf 'Running is not API readiness; check http://127.0.0.1:8000/v1/models.\n'
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}
case $1 in
prepare | start | stop | status) ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
[[ $STATE == /* ]] || fail 'XDG_DATA_HOME (or HOME) must be an absolute path'
command -v docker >/dev/null || fail 'Docker is required'
if [[ $1 != status ]]; then
  command -v flock >/dev/null || fail 'flock (util-linux) is required'
  mkdir -p -- "$STATE"
  exec 9>"$STATE/lifecycle.lock"
  flock --nonblock 9 || fail 'another lifecycle operation is in progress'
fi
"$1"
