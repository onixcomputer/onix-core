#!/usr/bin/env bash
set -euo pipefail

launcher=$(realpath "${1:?Pass the Niri session launcher.}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
export NIRI_TEST_WORK="$work" NIRI_TEST_BIN="$work/bin"
export PATH="$work/bin:$PATH"

printf '#!%s\n' "$BASH" >"$work/bin/check-context"
cat >>"$work/bin/check-context" <<'MOCK'
set -eu
fail() {
  printf 'Niri session test: %s\n' "$*" >&2
  touch "$NIRI_TEST_WORK/failure"
  exit 1
}
for name in XDG_SESSION_ID XDG_SEAT XDG_VTNR XDG_SESSION_TYPE; do
  case " $* " in
    *" $name "*) ;;
    *) fail "$name is absent from the variable list." ;;
  esac
done
test "${XDG_SESSION_ID-}" = "$NIRI_TEST_SESSION" || fail 'The session ID changed.'
test "${XDG_SEAT-}" = seat-test || fail 'The seat changed.'
test "${XDG_VTNR-}" = 7 || fail 'The terminal number changed.'
test "${XDG_SESSION_TYPE-}" = wayland || fail 'The session type is not Wayland.'
MOCK

printf '#!%s\n' "$BASH" >"$work/bin/systemctl"
cat >>"$work/bin/systemctl" <<'MOCK'
set -eu
printf 'systemctl %s\n' "$*" >> "$NIRI_TEST_WORK/calls"
case "$*" in
  '--user -q is-active niri.service') exit "${NIRI_TEST_ACTIVE:-1}" ;;
  '--user reset-failed') ;;
  '--user import-environment '*)
    shift 2
    "$NIRI_TEST_BIN/check-context" "$@"
    touch "$NIRI_TEST_WORK/systemd-import"
    ;;
  '--user --wait start niri.service')
    test -f "$NIRI_TEST_WORK/systemd-import"
    test -f "$NIRI_TEST_WORK/dbus-import"
    test ! -e "$NIRI_TEST_WORK/failure"
    ;;
  '--user start --job-mode=replace-irreversibly niri-shutdown.target') ;;
  '--user unset-environment '*)
    shift 2
    "$NIRI_TEST_BIN/check-context" "$@"
    touch "$NIRI_TEST_WORK/cleanup"
    ;;
  *) printf 'Unexpected systemctl call: %s\n' "$*" >&2; exit 1 ;;
esac
MOCK

printf '#!%s\n' "$BASH" >"$work/bin/dbus-update-activation-environment"
cat >>"$work/bin/dbus-update-activation-environment" <<'MOCK'
set -eu
printf 'dbus %s\n' "$*" >> "$NIRI_TEST_WORK/calls"
"$NIRI_TEST_BIN/check-context" "$@"
touch "$NIRI_TEST_WORK/dbus-import"
MOCK
chmod +x "$work/bin/"*

run_launcher() {
  env SHELL= MANAGERPID= SYSTEMD_EXEC_PID= \
    XDG_SESSION_ID="$NIRI_TEST_SESSION" XDG_SEAT=seat-test XDG_VTNR=7 \
    XDG_SESSION_TYPE=tty bash "$launcher"
}

# Two different IDs catch a fixed value or stale session context.
for session in c42 c99; do
  rm -f "$work/calls" "$work/failure" "$work/systemd-import" "$work/dbus-import" "$work/cleanup"
  export NIRI_TEST_SESSION="$session" NIRI_TEST_ACTIVE=1
  run_launcher
  test ! -e "$work/failure"
  test -f "$work/cleanup"
  grep -Fxq 'systemctl --user --wait start niri.service' "$work/calls"
  printf 'PASS: %s reaches systemd and D-Bus, then the launcher clears its context.\n' "$session"
done

# An existing compositor must block all imports and service changes.
rm -f "$work/calls" "$work/systemd-import" "$work/dbus-import" "$work/cleanup"
export NIRI_TEST_ACTIVE=0
if run_launcher >"$work/active-output" 2>&1; then
  printf 'The launcher accepted an existing Niri session.\n' >&2
  exit 1
fi
test "$(<"$work/calls")" = 'systemctl --user -q is-active niri.service'
test ! -e "$work/systemd-import"
test ! -e "$work/dbus-import"
test ! -e "$work/cleanup"
grep -Fxq 'A niri session is already running.' "$work/active-output"
printf 'PASS: an existing Niri session blocks a second launch.\n'
