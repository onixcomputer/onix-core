#!/usr/bin/env bash
# cutover.sh — stop the old V4.1 deployment on all three sparks and boot the 1017 pack.
# Runs ON the head (spark-e442). Rollback: `docker start vllm_dsv41` on all three
# (containers are stopped, never removed; see rollback.md).
set -uo pipefail
J="ssh -n -o BatchMode=yes -o ConnectTimeout=20 -i $HOME/.ssh/dspark-cluster"
R1="${R1:-dspark-worker}"
R2="${R2:-brittonr@192.168.1.233}"
MODEL_DIR="${MODEL_DIR:-DeepSeek-V4.1-Flash-1017-EXL3-TP3}"
LOG="${LOG:-/var/tmp/models/$MODEL_DIR/cutover.log}"
exec > >(tee -a "$LOG") 2>&1

echo "=== cutover $(date -Is) ==="
for tgt in "$R2" "$R1" local; do
  echo "-- stopping vllm_dsv41 on $tgt"
  if [ "$tgt" = local ]; then docker stop -t 60 vllm_dsv41; else $J "$tgt" "docker stop -t 60 vllm_dsv41"; fi
done
sleep 5
for tgt in "$R2" "$R1" local; do
  echo "-- state on $tgt"
  if [ "$tgt" = local ]; then docker ps -a --format '{{.Names}} {{.Status}}'; else $J "$tgt" "docker ps -a --format '{{.Names}} {{.Status}}'"; fi
done

echo "-- booting 1017 TP3"
bash "$HOME/boot_dsv41_1017.sh"

echo "-- waiting for the API (up to 45 min)"
for i in $(seq 1 90); do
  if curl -sf --max-time 10 localhost:8888/v1/models >/tmp/models.json 2>/dev/null; then
    echo "API up after $((i*30))s: $(cat /tmp/models.json | head -c 300)"
    break
  fi
  sleep 30
done
echo "=== cutover done $(date -Is) ==="
docker ps --format '{{.Names}} {{.Status}}'
