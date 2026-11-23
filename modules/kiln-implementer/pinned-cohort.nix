# The one qualified version set from the rev-pinned flake inputs
# (kiln-implementation, lattice-implementation, cairn-implementation,
# omp-implementation). compatibility-receipt.json records the same revisions,
# narHashes and executable identities; pinned-cohort-receipt checks they agree.
{ pkgs, lib, inputs }:
let
  system = pkgs.stdenv.hostPlatform.system;
  kiln = inputs.kiln-implementation.packages.${system};
  revisions = {
    kiln = inputs.kiln-implementation.rev;
    lattice = inputs.lattice-implementation.rev;
    cairn = inputs.cairn-implementation.rev;
    worker = inputs.omp-implementation.rev;
    nixpkgs = inputs.nixpkgs.rev;
  };
  components = {
    inherit revisions;
    lattice = inputs.lattice-implementation.packages.${system}.lattice;
    cairn = inputs.cairn-implementation.packages.${system}.cairn;
    worker = inputs.omp-implementation.packages.${system}.omp;
    # Kiln's typed worker-route contract (CLI transport v2, OMP revision pin).
    workflow = "${inputs.kiln-implementation}/config/implementation-worker.ncl";
  };
  construct = import ./cohort.nix { inherit pkgs lib; };
  campaign = import ./campaign-cohort.nix { inherit pkgs lib; };
  # The scripted VM's Kiln: Kiln's own explicit `implementation-fixtures`
  # build (protocol-fixtures publisher, implementation-fixtures verifier),
  # plus the production `kiln` CLI, which that build does not include and
  # the campaign cohort admits as its native-Git program.
  fixtureKiln = pkgs.runCommand "kiln-implementation-fixture-kiln" { } ''
    mkdir -p "$out/bin" "$out/share"
    for program in ${kiln.implementation-fixtures}/bin/*; do
      ln -s "$program" "$out/bin/"
    done
    ln -s ${kiln.kiln}/bin/kiln "$out/bin/kiln"
    ln -s ${kiln.implementation-fixtures}/share/kiln "$out/share/kiln"
  '';
in
{
  inherit revisions;
  # Live stages: the production Kiln workspace build.
  cohort = construct (components // { kiln = kiln.kiln; });
  campaignCohort = campaign (components // { kiln = kiln.kiln; });
  # Scripted VM inputs; never selected by a live configuration.
  fixtureCohort = construct (components // { kiln = fixtureKiln; });
  fixtureHelper = kiln.implementation-fixtures;
  cairnSource = inputs.cairn-implementation;
  cairnPolicy = "${inputs.cairn-implementation}/cairn-policy/generated/cairn-policy.json";
}
