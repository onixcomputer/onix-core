# Caller supplies the actual frozen source/package cohort. No canary/default or
# evaluation-only empty package can stand in for an executed consumer.
{ pkgs, lib, cohort, fixtureHelper, cairnSource, cairnPolicy }:
let
  fixture = import ../tests/kiln-implementation-scripted-bundle.nix {
    inherit pkgs lib cohort fixtureHelper cairnSource cairnPolicy;
  };
in {
  packages.kiln-implementation-scripted-inputs = fixture;
  checks.kiln-implementation-scripted-vm = import ../tests/kiln-implementation-scripted-vm.nix {
    inherit pkgs lib fixture;
  };
}
