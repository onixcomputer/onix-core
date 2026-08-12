let fixture = import "valid-custom-model.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.meshBackend.localModel.sha256 | force = "not-a-sha256",
  }
) | DgxMachines
