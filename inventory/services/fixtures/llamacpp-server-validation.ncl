let sc = import "../settings-contracts.ncl" in
let default_port = 13305 in
let default_context_size = 8192 in
let default_gpu_layers = 999 in
let default_worker_threads = 8 in
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
        modelSha256 = "dcd147f24f8749420ebc784c5b9c75ca2c0d2ced2e6f365be18ed97a4508d488",
        extraModelFiles = ["VibeThinker-3B-00002-of-00002.gguf"],
        extraModelSha256 = ["013945eb68cd4afefc8a1751c099ba2afcb29a4209feb649095985fa89fb1437"],
        multimodalProjectorFile = "mmproj-VibeThinker-3B.F16.gguf",
        multimodalProjectorSha256 = "2cdb98b37615fc481fdb624ee20e02ee735b61a81ce43d58e16218fc9055c588",
        huggingFaceTokenRequired = true,
        modelAlias = "VibeThinker-3B",
        gpuLayers = default_gpu_layers,
        metaliumDeviceId = default_metalium_device_id,
        metaliumInspectorPort = default_metalium_inspector_port,
        metaliumTrace = true,
        contextSize = default_context_size,
        generationThreads = default_worker_threads,
        batchThreads = default_worker_threads,
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
        modelSha256 = 42,
        extraModelSha256 = [42],
        multimodalProjectorFile = 42,
        multimodalProjectorSha256 = 42,
        huggingFaceTokenRequired = "required",
        metaliumDeviceId = "device-zero",
        metaliumInspectorPort = 70000,
        metaliumTrace = "enabled",
        generationThreads = "eight",
        batchThreads = "eight",
        flashAttention = "disabled",
      },
}
