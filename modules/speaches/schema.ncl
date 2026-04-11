{
  default = {
    stateDir = { type = "string", default = "/var/lib/speaches", description = "Persistent state directory for Speaches model cache" },
    image = { type = "string", default = "ghcr.io/speaches-ai/speaches:0.9.0-rc.3-cpu@sha256:2163775b6df5e451a71200e8f675fed68dbd8ab184fc604453d549e486f22fd2", description = "OCI image for the Speaches STT/TTS server" },
    host = { type = "string", default = "127.0.0.1", description = "Host address Speaches binds to" },
    port = { type = "port", default = 8001, description = "Port for the Speaches OpenAI-compatible speech API" },
    enableGPU = { type = "bool", default = false, description = "Expose NVIDIA GPUs to the container with --gpus=all" },
    enableUi = { type = "bool", default = false, description = "Enable the Speaches built-in Gradio UI" },
    logLevel = { type = "string", default = "info", description = "Speaches log level" },
    models = { type = "array_string", default = [], description = "Model IDs to preload during startup" },
    modelAliases = { type = "record", default = {}, description = "Alias mapping written to model_aliases.json, e.g. { \"whisper-1\" = \"Systran/faster-whisper-large-v3\" }" },
    sttModelTtl = { type = "number", default = -1, description = "Seconds to keep STT models loaded after use (-1 keeps them resident)" },
    ttsModelTtl = { type = "number", default = -1, description = "Seconds to keep TTS models loaded after use (-1 keeps them resident)" },
    whisperComputeType = { type = "string", default = "default", description = "faster-whisper compute type, e.g. float16 or int8_float16" },
  },
}
