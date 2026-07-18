{
  lib,
  runCommand,
  stdenv,
  b3sum,
  rustc,
  shellcheck,
}:
let
  activeRoot = ../../cairn/changes/prepare-rwkv-persistent-metalium-device-4-run;
  archivedRoot = ../../cairn/archive/2026-07-18-prepare-rwkv-persistent-metalium-device-4-run;
  runbookRoot = if builtins.pathExists activeRoot then activeRoot else archivedRoot;
  runbook = builtins.path {
    path = runbookRoot + "/run-one-shot.sh";
    name = "rwkv-persistent-device-4-run-one-shot.sh";
  };
  checker = builtins.path {
    path = runbookRoot + "/check-runbook.rs";
    name = "rwkv-persistent-device-4-check-runbook.rs";
  };
  expectedRunbookBlake3 = "9f4dac687763712ecf527707673bf1502b3a9ab53b77e365963f8dea7864998f";
  expectedCheckerBlake3 = "39d914c48447f1f8205a3c16fd8ae5141ac295a91c8e1838ec7b4ddc2bdb452e";
  checkerRustStartLine = 6;
  executableMode = 755;
in
runCommand "rwkv-ttwkv7-persistent-device-4-runbook-check"
  {
    nativeBuildInputs = [
      b3sum
      rustc
      shellcheck
      stdenv.cc
    ];
  }
  ''
    set -euo pipefail

    test "$(b3sum ${lib.escapeShellArg runbook} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedRunbookBlake3}
    test "$(b3sum ${lib.escapeShellArg checker} | cut -d' ' -f1)" = \
      ${lib.escapeShellArg expectedCheckerBlake3}

    cp ${lib.escapeShellArg runbook} run-one-shot.sh
    chmod ${toString executableMode} run-one-shot.sh
    bash -n run-one-shot.sh
    shellcheck run-one-shot.sh

    tail -n +${toString checkerRustStartLine} ${lib.escapeShellArg checker} >check-runbook.rs
    rustc --edition=2024 check-runbook.rs -o check-runbook
    ./check-runbook run-one-shot.sh >check.log
    ./check-runbook --self-test run-one-shot.sh >self-test.log
    grep -F 'rwkv persistent device-4 runbook check: PASS' check.log
    grep -F 'rwkv persistent device-4 runbook self-test: PASS' self-test.log
    if ./check-runbook run-one-shot.sh unexpected >suffix.log 2>&1; then
      echo 'device-4 runbook checker accepted an argument suffix' >&2
      exit 1
    fi
    grep -F 'usage: check-runbook.rs' suffix.log

    mkdir -p "$out"
    cp check.log "$out/check.log"
    cp self-test.log "$out/self-test.log"
    printf '%s\n' \
      '{' \
      '  "device_initialized": false,' \
      '  "hardware_process_started": false,' \
      '  "runbook_blake3": "${expectedRunbookBlake3}",' \
      '  "checker_blake3": "${expectedCheckerBlake3}",' \
      '  "target": "rwkv_ttwkv7_persistent_device_4_runbook"' \
      '}' \
      >"$out/receipt.json"
  ''
