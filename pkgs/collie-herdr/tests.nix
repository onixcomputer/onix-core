# Exercise the controller without systemd, Tailscale, or live Herdr effects.
{
  pkgs,
  lib,
  collie,
}:
let
  failureStatus = 23;
  stateRoot = "state-home";
in
pkgs.runCommand "collie-managed-controller" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
  set -eu
  export HOME="$TMPDIR/home"
  export XDG_STATE_HOME="$TMPDIR/${stateRoot}"
  export CALL_LOG="$TMPDIR/calls"
  export STATE_LOG="$TMPDIR/state-path"
  mkdir -p "$HOME" "$TMPDIR/controller"
  controller="$TMPDIR/controller/collie-ctl.sh"

  cat > "$TMPDIR/systemctl" <<'SCRIPT'
  #!${pkgs.bash}/bin/bash
  set -eu
  printf 'systemctl %s\n' "$*" >> "$CALL_LOG"
  exit "''${SYSTEMCTL_EXIT_CODE:-0}"
  SCRIPT
  chmod +x "$TMPDIR/systemctl"

  cat > "$TMPDIR/controller/collie-ctl-upstream.sh" <<'SCRIPT'
  #!${pkgs.bash}/bin/bash
  set -eu
  printf 'upstream %s\n' "$*" >> "$CALL_LOG"
  printf '%s\n' "$HERDR_PLUGIN_STATE_DIR" > "$STATE_LOG"
  SCRIPT

  substitute ${./managed-ctl.sh} "$controller" \
    --replace-fail '#!/usr/bin/env bash' '#!${pkgs.bash}/bin/bash' \
    --replace-fail '@bash@' '${pkgs.bash}' \
    --replace-fail '@runtimePath@' '${lib.makeBinPath [ pkgs.coreutils ]}' \
    --replace-fail '@systemctl@' "$TMPDIR/systemctl"
  chmod +x "$controller"
  shellcheck "$controller"

  for action in start stop restart; do
    : > "$CALL_LOG"
    "$controller" "$action"
    printf 'systemctl --user %s collie.service\n' "$action" > "$TMPDIR/expected"
    cmp "$CALL_LOG" "$TMPDIR/expected"
  done

  for action in status url version push-test; do
    : > "$CALL_LOG"
    HERDR_PLUGIN_STATE_DIR="$TMPDIR/unrelated-state" "$controller" "$action"
    printf 'upstream %s\n' "$action" > "$TMPDIR/expected"
    cmp "$CALL_LOG" "$TMPDIR/expected"
    printf '%s/collie\n' "$XDG_STATE_HOME" > "$TMPDIR/expected-state"
    cmp "$STATE_LOG" "$TMPDIR/expected-state"
  done

  for action in build update uninstall serve unserve _apply-update _exec-bridge bogus; do
    : > "$CALL_LOG"
    if "$controller" "$action" > "$TMPDIR/stdout" 2> "$TMPDIR/stderr"; then
      echo "negative: protected or unknown action accepted: $action" >&2
      exit 1
    fi
    test ! -s "$CALL_LOG"
    test -s "$TMPDIR/stderr"
  done

  : > "$CALL_LOG"
  if "$controller" start extra > "$TMPDIR/stdout" 2> "$TMPDIR/stderr"; then
    echo 'negative: extra service arguments accepted' >&2
    exit 1
  fi
  test ! -s "$CALL_LOG"

  if SYSTEMCTL_EXIT_CODE=${toString failureStatus} "$controller" start; then
    echo 'negative: systemctl failure was hidden' >&2
    exit 1
  else
    actual_status=$?
    test "$actual_status" -eq ${toString failureStatus}
  fi

  # The installed entry point must also work without an ambient tool PATH.
  env -i HOME="$HOME" PATH= ${collie}/bin/collie-ctl help > "$TMPDIR/help"
  ${pkgs.gnugrep}/bin/grep -Fq 'Usage: collie-ctl' "$TMPDIR/help"
  ${collie}/bin/collie-ctl version > "$TMPDIR/version"
  ${pkgs.gnugrep}/bin/grep -Fq '${collie.version}' "$TMPDIR/version"
  if ${collie}/bin/collie-ctl uninstall > "$TMPDIR/stdout" 2> "$TMPDIR/stderr"; then
    echo 'negative: installed controller admitted uninstall' >&2
    exit 1
  fi
  touch "$out"
''
