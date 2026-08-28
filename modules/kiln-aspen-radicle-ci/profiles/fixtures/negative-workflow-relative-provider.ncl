let make_workflow = import "../lattice-workflow.ncl" in
make_workflow {
  provider_executable = "bin/kiln-radicle-nix-provider",
  provider_profile = "/etc/kiln-aspen-ci/provider-profile.json",
  repository = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
  command_timeout_seconds = 7260,
}
