# r[impl onix.kiln_implementation.guest]
# Deployment-bound composition, not a shared package definition.
{ pkgs, lib }:
{ kiln, lattice, cairn, worker, workflow, revisions, workerAdapter ? "omp", sourceCohorts ? { } }:
assert lib.assertMsg (workerAdapter == "omp") "This composition selects the explicit OMP adapter; Pi is not qualified by this profile";
assert lib.assertMsg (lib.all (name: builtins.match "[0-9a-f]{40}" (revisions.${name} or "") != null) [ "kiln" "lattice" "cairn" "worker" "nixpkgs" ]) "Every cohort component requires an immutable source revision";
assert lib.assertMsg (revisions.worker == "e325ffc73ab86e03bdd20a91b77d8e2b3964c906") "OMP must match the actual Lattice JSONL adapter reference revision";
let
  sourceCohortValid = name: value:
    builtins.elem name [ "kiln" "lattice" "cairn" "worker" "nixpkgs" ]
    && builtins.isAttrs value
    && lib.sort builtins.lessThan (builtins.attrNames value) == lib.sort builtins.lessThan [ "kind" "repository" "baseline_revision" "baseline_archive_blake3" "patch_blake3" "source_archive_blake3" "source_nar_hash" "source_scope" ]
    && value.kind == "unpublished_candidate"
    && builtins.isString value.repository && value.repository != ""
    && value.baseline_revision == revisions.${name}
    && lib.all (field: builtins.match "[0-9a-f]{64}" value.${field} != null) [ "baseline_archive_blake3" "patch_blake3" "source_archive_blake3" ]
    && builtins.match "sha256-[A-Za-z0-9+/]{43}=" value.source_nar_hash != null
    && builtins.isList value.source_scope && value.source_scope != [ ]
    && lib.all (path: builtins.isString path && path != "" && !(lib.hasPrefix "/" path) && !(lib.hasInfix ".." path)) value.source_scope;
  entries = {
    coordinator = { path = "${kiln}/bin/kiln-implementer"; revision = revisions.kiln; };
    verifier = { path = "${kiln}/bin/kiln-web-service"; revision = revisions.kiln; };
    dispatch = { path = "${kiln}/bin/kiln-lattice-dispatch"; revision = revisions.kiln; };
    cairn_intake = { path = "${kiln}/bin/kiln-cairn-intake"; revision = revisions.kiln; };
    lattice = { path = "${lattice}/bin/lattice"; revision = revisions.lattice; };
    cairn = { path = "${cairn}/bin/cairn"; revision = revisions.cairn; };
    worker = { path = "${worker}/bin/${workerAdapter}"; revision = revisions.worker; };
    sandbox = { path = "${pkgs.bubblewrap}/bin/bwrap"; revision = revisions.nixpkgs; };
    nix = { path = "${pkgs.nix}/bin/nix"; revision = revisions.nixpkgs; };
    git = { path = "${pkgs.git}/bin/git"; revision = revisions.nixpkgs; };
    # Lattice's attempt-local model broker: the pinned relay and shell it
    # checks by BLAKE3 before starting the worker.
    relay = { path = "${pkgs.socat}/bin/socat"; revision = revisions.nixpkgs; };
    shell = { path = "${pkgs.bash}/bin/bash"; revision = revisions.nixpkgs; };
  };
  declared = pkgs.writeText "kiln-implementation-cohort-declared.json" (builtins.toJSON {
    schema = "onix.kiln.implementation-cohort.v1";
    inherit entries workerAdapter revisions sourceCohorts;
    workflow = toString workflow;
    qualification = "unqualified";
  });
  environment = pkgs.buildEnv {
    name = "kiln-implementation-environment";
    paths = [ kiln lattice cairn worker pkgs.nix pkgs.git pkgs.bash pkgs.coreutils pkgs.bubblewrap ];
    pathsToLink = [ "/bin" ];
  };
in
assert lib.assertMsg (lib.all (name: sourceCohortValid name sourceCohorts.${name}) (builtins.attrNames sourceCohorts)) "Unsupported or incomplete unpublished source identity claims";
pkgs.runCommand "kiln-implementation-cohort" {
  nativeBuildInputs = [ pkgs.python3 pkgs.b3sum ];
  passthru = { inherit environment kiln lattice cairn worker workflow entries; };
} ''
  mkdir -p "$out"
  ln -s ${environment} "$out/environment"
  ln -s ${workflow} "$out/workflow.ncl"
  # Reject old canary Lattice builds instead of assuming a binary named lattice
  # implements the unpublished bounded implementation consumer.
  ${lattice}/bin/lattice implementation-attempt --help > /dev/null
  python3 - ${declared} "$out/manifest.json" <<'PY'
  import json, pathlib, subprocess, sys
  manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
  for entry in manifest["entries"].values():
      executable = pathlib.Path(entry["path"]).resolve(strict=True)
      if not executable.is_file() or not executable.stat().st_mode & 0o111:
          raise SystemExit("cohort requires the actual executable: " + str(executable))
      entry["resolved_path"] = str(executable)
      entry["blake3"] = subprocess.check_output(["b3sum", "--no-names", str(executable)], text=True).strip()
  manifest["workflow_blake3"] = subprocess.check_output(["b3sum", "--no-names", manifest["workflow"]], text=True).strip()
  pathlib.Path(sys.argv[2]).write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
  PY
''
