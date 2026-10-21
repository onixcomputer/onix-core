{
  server = {
    backend = { type = "enum", values = ["cpu", "vulkan-compensated-fp32"], default = "cpu", description = "Laya runtime: CPU or native RADV Vulkan compensated FP32" },
    host = { type = "string", default = "127.0.0.1", description = "Loopback or Tailscale IPv4 bind address" },
    port = { type = "port", default = 7999, description = "Private JSON API port" },
    revision = { type = "string", default = "1c5edc17a7acd8701df6fc341c0d179f1c62c982", description = "Immutable Hugging Face resource commit" },
  },
}
