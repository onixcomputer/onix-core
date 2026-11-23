# shellcheck shell=bash
env_file="/etc/vllm-cluster/network.env"

if [ ! -r "$env_file" ]; then
  echo "missing vLLM cluster env file: $env_file" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  cat "$env_file"
  exit 0
fi

set -a
# shellcheck disable=SC1090,SC1091
. "$env_file"
set +a

exec "$@"
