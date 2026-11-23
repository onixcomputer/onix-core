# Selected-Cairn campaign-only capability admission; the historical cohort is unchanged.
{ pkgs, lib }:
args:
let
  cohort = (import ./cohort.nix { inherit pkgs lib; }) args;
  nativeGitEntry = { path = "${args.kiln}/bin/kiln"; revision = args.revisions.kiln; };
in
pkgs.runCommand "kiln-selected-cairn-campaign-cohort" {
  nativeBuildInputs = [ pkgs.jq pkgs.b3sum ];
  passthru = cohort.passthru // {
    inherit cohort;
    entries = cohort.entries // { native_git = nativeGitEntry; };
  };
} ''
  set -eu
  cairn="$(${pkgs.jq}/bin/jq -er '.entries.cairn.resolved_path' ${cohort}/manifest.json)"
  lattice="$(${pkgs.jq}/bin/jq -er '.entries.lattice.resolved_path' ${cohort}/manifest.json)"
  cairn_help="$("$cairn" --help 2>&1)"
  case "$cairn_help" in *implementation-ready*) ;; *) echo "selected Cairn cohort lacks implementation-ready" >&2; exit 1;; esac
  case "$cairn_help" in *"workflow instructions"*) ;; *) echo "selected Cairn cohort lacks workflow instructions" >&2; exit 1;; esac
  lattice_help="$("$lattice" implementation-attempt --help 2>&1)"
  case "$lattice_help" in *prepare*) ;; *) echo "selected Lattice cohort lacks native campaign preparation" >&2; exit 1;; esac
  case "$lattice_help" in *export-candidate*) ;; *) echo "selected Lattice cohort lacks candidate export" >&2; exit 1;; esac
  native_git=${lib.escapeShellArg nativeGitEntry.path}
  native_git_resolved="$(readlink -e "$native_git")"
  test -f "$native_git_resolved" && test -x "$native_git_resolved"
  native_git_blake3="$(b3sum --no-names "$native_git_resolved")"
  mkdir -p "$out"
  ln -s ${cohort}/environment "$out/environment"
  ln -s ${cohort}/workflow.ncl "$out/workflow.ncl"
  jq --arg path "$native_git" --arg resolved_path "$native_git_resolved" \
    --arg blake3 "$native_git_blake3" --arg revision ${lib.escapeShellArg nativeGitEntry.revision} \
    '.entries.native_git = {path:$path,resolved_path:$resolved_path,blake3:$blake3,revision:$revision}' \
    ${cohort}/manifest.json > "$out/manifest.json"
''
