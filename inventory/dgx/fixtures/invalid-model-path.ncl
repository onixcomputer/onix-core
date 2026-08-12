let fixture = import "valid-custom-model.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.meshBackend.localModel.file | force = "../fixture-Q4_K_M.gguf",
  }
) | DgxMachines
