# Fails when compatibility-receipt.json drifts from the locked inputs or from
# the executable/workflow identities the pinned cohort actually builds.
{
  pkgs,
  lib,
  pinned,
  inputs,
}:
let
  receipt = lib.importJSON ./compatibility-receipt.json;
  locked = lib.mapAttrs (name: _: {
    rev = inputs.${name}.rev;
    narHash = inputs.${name}.narHash;
  }) receipt.inputs;
  drift = lib.filterAttrs (
    name: value:
    value.rev != receipt.inputs.${name}.rev || value.narHash != receipt.inputs.${name}.narHash
  ) locked;
in
assert lib.assertMsg (
  drift == { }
) "compatibility receipt inputs differ from flake.lock: ${builtins.toJSON drift}";
pkgs.runCommand "kiln-implementation-compatibility-receipt" { nativeBuildInputs = [ pkgs.jq ]; } ''
  set -eu
  for cohort in live:${pinned.cohort} scripted:${pinned.fixtureCohort}; do
    name="''${cohort%%:*}"
    manifest="''${cohort#*:}/manifest.json"
    jq -e --slurpfile receipt ${./compatibility-receipt.json} --arg name "$name" '
      ($receipt[0].cohorts[$name]) as $expected
      | (.entries | map_values({resolved_path, blake3, revision})) == $expected.executables
        and .workflow_blake3 == $expected.workflow_blake3
        and .revisions == $receipt[0].revisions' "$manifest" > /dev/null \
      || { echo "receipt $name cohort differs from the built manifest" >&2; exit 1; }
  done
  mkdir -p "$out"
  cp ${./compatibility-receipt.json} "$out/compatibility-receipt.json"
''
