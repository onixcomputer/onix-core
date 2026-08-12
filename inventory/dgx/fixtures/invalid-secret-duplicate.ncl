let fixture = import "valid.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.runtimeSecrets.meshJoinToken | force = "DGX_FIXTURE_TAILSCALE_AUTH_KEY",
  }
) | DgxMachines
