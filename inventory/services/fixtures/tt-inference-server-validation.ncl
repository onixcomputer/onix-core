let sc = import "../settings-contracts.ncl" in
let loopback_host = "127.0.0.1" in
let default_port = 8000 in
let p150_device_id = 1 in
let container_uid = 1000 in
let pinned_image = "ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.18.0-c49bb76-6b4a3a7@sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff" in
{
  positive =
    sc.validate_fields
      "tt-inference-server:default"
      "tt-inference-server-llama-positive"
      {
        stateDir = "/var/lib/tt-inference-server-llama-3-1-8b-instruct",
        image = pinned_image,
        model = "meta-llama/Llama-3.1-8B-Instruct",
        device = "p150",
        physicalDeviceId = p150_device_id,
        host = loopback_host,
        port = default_port,
        cacheUid = container_uid,
        cacheGid = container_uid,
        enableTraceCapture = true,
        autoStart = true,
        extraArgs = [],
      },
  negative =
    sc.validate_fields
      "tt-inference-server:default"
      "tt-inference-server-llama-negative"
      {
        image = 42,
        model = false,
        device = "p150x2",
        physicalDeviceId = "card-one",
        host = 0,
        port = 70000,
        cacheUid = "container-user",
        cacheGid = "container-group",
        enableTraceCapture = "enabled",
        autoStart = "yes",
        extraArgs = "--no-auth",
      },
}
