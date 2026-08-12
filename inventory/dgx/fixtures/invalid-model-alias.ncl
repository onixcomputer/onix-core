let fixture = import "valid-custom-model.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.meshBackend.modelAlias | force = "different-model",
  }
) | DgxMachines
