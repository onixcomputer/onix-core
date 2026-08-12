let fixture = import "valid.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.meshBackend.unit | force = "not a service",
  }
) | DgxMachines
