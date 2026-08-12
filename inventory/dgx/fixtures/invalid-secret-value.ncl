let fixture = import "valid.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.runtimeSecrets.tailscaleAuthKey | force = "tskey-auth-secret-value",
  }
) | DgxMachines
