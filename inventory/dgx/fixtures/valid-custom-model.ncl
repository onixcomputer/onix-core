let fixture = import "valid.ncl" in
let { DgxMachines, .. } = import "../contracts.ncl" in

(
  fixture
  & {
    machines.fixture-dgx.meshBackend.modelAlias | force = "fixture-custom-q4",
    machines.fixture-dgx.meshBackend.localModel = {
      alias = "fixture-custom-q4",
      repository = "fixture-owner/fixture-gguf",
      revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      file = "models/fixture-Q4_K_M.gguf",
      sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      contextSize = 4096,
      gpuLayers = 999,
      flashAttention = true,
      noMmap = true,
      enableMetrics = true,
      extraArgs = [],
    },
  }
) | DgxMachines
