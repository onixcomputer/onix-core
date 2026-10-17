#!/usr/bin/env bash
# Repair one isolated Trellis sequence-fold proof with OpenCode and local Nemotron.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/nemotron-verus/loop.py" "$@"
