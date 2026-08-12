let fixture = import "valid.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.accessPolicy | force = "shared-keys",
  }
) | DgxMachines
