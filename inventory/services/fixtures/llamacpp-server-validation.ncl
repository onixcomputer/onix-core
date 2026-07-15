let sc = import "../settings-contracts.ncl" in
let default_port = 13305 in
let default_context_size = 8192 in
let default_gpu_layers = 999 in
let default_batch_size = 512 in
let default_parallel_slots = 1 in
let default_metalium_device_id = 0 in
let default_metalium_inspector_port = 50051 in
{
  positive =
    sc.validate_fields
      "llamacpp-server:server"
      "llamacpp-server-metalium-positive"
      {
        host = "127.0.0.1",
        port = default_port,
        backend = "metalium",
        modelRepo = "prithivMLmods/VibeThinker-3B-GGUF",
        modelFile = "VibeThinker-3B.Q8_0.gguf",
        modelRevision = "main",
        modelAlias = "VibeThinker-3B",
        gpuLayers = default_gpu_layers,
        metaliumDeviceId = default_metalium_device_id,
        metaliumInspectorPort = default_metalium_inspector_port,
        contextSize = default_context_size,
        batchSize = default_batch_size,
        ubatchSize = default_batch_size,
        parallelSlots = default_parallel_slots,
        cacheTypeK = null,
        cacheTypeV = null,
        flashAttention = false,
        noMmap = true,
        enableMetrics = true,
        autoStart = true,
        extraArgs = ["--fit", "off"],
      },
  negative =
    sc.validate_fields
      "llamacpp-server:server"
      "llamacpp-server-metalium-negative"
      {
        backend = "unsupported-backend",
        metaliumDeviceId = "device-zero",
        metaliumInspectorPort = 70000,
        flashAttention = "disabled",
      },
}
