#!/usr/bin/env bash
# Nix owns installation and publication. This adapter controls only the bridge.
set -euo pipefail
export PATH="@runtimePath@${PATH:+:$PATH}"
readonly service=collie.service
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir

# Herdr injects its own state directory. Match the independently supervised bridge.
export HERDR_PLUGIN_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/collie"
export HERDR_PLUGIN_CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/config/herdr.collie}"

case "${1:-help}" in
start | stop | restart)
  if [ "$#" -ne 1 ]; then
    printf 'This action does not accept extra arguments.\n' >&2
    exit 1
  fi
  exec @systemctl@ --user "$1" "$service"
  ;;
status | url | version | push-test)
  exec @bash@/bin/bash "$script_dir/collie-ctl-upstream.sh" "$@"
  ;;
build | update | uninstall | _apply-update | _exec-bridge)
  printf 'Nix owns Collie installation. Change its package or Home Manager config, then deploy the host.\n' >&2
  exit 1
  ;;
serve | unserve)
  printf 'The NixOS collie-serve.service owns publication. This command cannot change Tailscale Serve.\n' >&2
  exit 1
  ;;
help | --help | -h)
  printf 'Usage: collie-ctl {start|stop|restart|status|url|version|push-test}\n'
  ;;
*)
  printf 'Unknown Collie action: %s\n' "$1" >&2
  exit 1
  ;;
esac
