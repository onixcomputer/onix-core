{
  lib,
  nickel,
  rustPlatform,
}:
let
  blake3HexLength = 64;
  mismatchedPlanId = builtins.concatStringsSep "" (builtins.genList (_: "d") blake3HexLength);
in
rustPlatform.buildRustPackage {
  pname = "rwkv-lab";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  postInstall = ''
    mkdir -p "$out/share/rwkv-lab/examples"
    cp ${./session-contract.ncl} "$out/share/rwkv-lab/session-contract.ncl"
    cp ${./fixtures/valid-session.ncl} "$out/share/rwkv-lab/examples/valid-session.ncl"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ nickel ];
  installCheckPhase = ''
    runHook preInstallCheck
    set -euo pipefail

    fixture_root="$(mktemp -d)"
    manifest_json="$fixture_root/manifest.json"
    ${lib.getExe nickel} export --format json \
      "$out/share/rwkv-lab/examples/valid-session.ncl" \
      >"$manifest_json"

    plan_id="$($out/bin/rwkv-lab plan-id "$manifest_json")"
    test "''${#plan_id}" -eq ${toString blake3HexLength}
    $out/bin/rwkv-lab check "$manifest_json" >"$fixture_root/plan-receipt.json"
    grep -F '"plan_id":' "$fixture_root/plan-receipt.json"
    grep -F '"session_id": "reader-l1-repair-device-1"' "$fixture_root/plan-receipt.json"

    instantiate_evidence() {
      source_path="$1"
      destination_path="$2"
      substitute "$source_path" "$destination_path" \
        --replace-fail '@planId@' "$plan_id"
    }

    instantiate_evidence ${./fixtures/passed-evidence.json.in} "$fixture_root/passed.json"
    instantiate_evidence ${./fixtures/partial-evidence.json.in} "$fixture_root/partial.json"
    instantiate_evidence ${./fixtures/unsafe-evidence.json.in} "$fixture_root/unsafe.json"

    $out/bin/rwkv-lab classify "$manifest_json" "$fixture_root/passed.json" \
      >"$fixture_root/passed-receipt.json"
    grep -F '"outcome": "passed"' "$fixture_root/passed-receipt.json"
    grep -F '"process_budget_exhausted": true' "$fixture_root/passed-receipt.json"
    grep -F '"success_claim": "The exact data-movement session completed with its reviewed evidence."' \
      "$fixture_root/passed-receipt.json"

    $out/bin/rwkv-lab classify "$manifest_json" "$fixture_root/partial.json" \
      >"$fixture_root/partial-receipt.json"
    grep -F '"outcome": "partial_diagnostic"' "$fixture_root/partial-receipt.json"
    grep -F '"diagnostic_log"' "$fixture_root/partial-receipt.json"
    grep -F '"success_claim": null' "$fixture_root/partial-receipt.json"

    $out/bin/rwkv-lab classify "$manifest_json" "$fixture_root/unsafe.json" \
      >"$fixture_root/unsafe-receipt.json"
    grep -F '"outcome": "unsafe"' "$fixture_root/unsafe-receipt.json"
    grep -F 'process attempts exceeded the manifest budget' "$fixture_root/unsafe-receipt.json"
    grep -F '"success_claim": null' "$fixture_root/unsafe-receipt.json"

    nickel_fixture_root="$fixture_root/nickel"
    mkdir -p "$nickel_fixture_root/fixtures"
    cp ${./session-contract.ncl} "$nickel_fixture_root/session-contract.ncl"
    cp ${./fixtures/invalid-session-type.ncl} \
      "$nickel_fixture_root/fixtures/invalid-session-type.ncl"
    cp ${./fixtures/invalid-session-semantics.ncl} \
      "$nickel_fixture_root/fixtures/invalid-session-semantics.ncl"

    if ${lib.getExe nickel} export --format json \
      "$nickel_fixture_root/fixtures/invalid-session-type.ncl" \
      >"$fixture_root/invalid-type.json" 2>"$fixture_root/invalid-type.log"; then
      echo "rwkv-lab Nickel contract accepted an invalid process-budget type" >&2
      exit 1
    fi
    test -s "$fixture_root/invalid-type.log"

    ${lib.getExe nickel} export --format json \
      "$nickel_fixture_root/fixtures/invalid-session-semantics.ncl" \
      >"$fixture_root/invalid-semantics.json"
    if $out/bin/rwkv-lab check "$fixture_root/invalid-semantics.json" \
      >"$fixture_root/invalid-semantics.log" 2>&1; then
      echo "rwkv-lab accepted an invalid semantic manifest" >&2
      exit 1
    fi
    grep -F 'rollback_delay_seconds must exceed timeout plus kill grace' \
      "$fixture_root/invalid-semantics.log"

    substitute ${./fixtures/passed-evidence.json.in} "$fixture_root/mismatched-plan.json" \
      --replace-fail '@planId@' ${lib.escapeShellArg mismatchedPlanId}
    if $out/bin/rwkv-lab classify "$manifest_json" "$fixture_root/mismatched-plan.json" \
      >"$fixture_root/mismatched-plan.log" 2>&1; then
      echo "rwkv-lab accepted evidence bound to another plan" >&2
      exit 1
    fi
    grep -F 'evidence plan_id does not match' "$fixture_root/mismatched-plan.log"

    $out/bin/rwkv-lab --help >"$fixture_root/help.log"
    grep -F 'check MANIFEST.json' "$fixture_root/help.log"
    grep -F 'plan-id MANIFEST.json' "$fixture_root/help.log"
    grep -F 'classify MANIFEST.json EVIDENCE.json' "$fixture_root/help.log"

    if $out/bin/rwkv-lab check /dev/null >"$fixture_root/device-node.log" 2>&1; then
      echo "rwkv-lab accepted a device node as manifest input" >&2
      exit 1
    fi
    grep -F 'manifest must resolve to a regular file' "$fixture_root/device-node.log"

    if grep -E 'std::process::Command|Command::new|TT_VISIBLE_DEVICES|owner-control.*isolate' \
      ${./src/lib.rs} ${./src/main.rs}; then
      echo "rwkv-lab must not contain a process or hardware orchestration path" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Device-free bounded RWKV session plan and evidence receipts";
    license = lib.licenses.mit;
    mainProgram = "rwkv-lab";
    platforms = lib.platforms.linux;
  };
}
