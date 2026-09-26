let default_api_port = 9337 in
let default_console_port = 3131 in
let default_mesh_port = 47916 in
let default_proxy_activation_context_size = 512 in
{
  default = {
    mode = { type = "enum", values = ["seed", "joiner"], default = "seed", description = "Whether this node creates the private mesh or joins with a managed credential" },
    endpointUrl = { type = "string", default = "http://127.0.0.1:13305/v1", description = "Local OpenAI-compatible endpoint advertised by the openai-endpoint plugin" },
    extraEndpoints = { type = "record", default = {}, description = "Additional externally managed loopback OpenAI /v1 endpoints keyed by plugin name; openai-endpoint is reserved for endpointUrl" },
    researchMode = { type = "enum", values = ["disabled", "provider", "forwarder"], default = "disabled", description = "Native research plugin: local provider or authenticated peer-stream forwarder" },
    researchArxivAddress = { type = "nullable_string", default = null, description = "Optional provider-only private arXiv backend IP:port; null disables corpus operations on this peer" },
    researchLayaAddress = { type = "nullable_string", default = null, description = "Optional provider-only private Laya backend IP:port; null disables Laya operations on this peer" },
    researchTargetPeer = { type = "string", default = "", description = "Forwarder-only full lowercase Mesh peer ID of the research provider" },
    researchBackendUnits = { type = "array_string", default = [], description = "Local research service units ordered before the provider sidecar" },
    researchHttpBindAddress = { type = "nullable_string", default = null, description = "Optional Tailscale address for research-only HTTP ingress; never exposes the Mesh management API" },
    researchHttpPort = { type = "port", default = 7997, description = "Private research-only HTTP ingress port" },
    proxyActivationModel = { type = "string", default = "Qwen3-0.6B-Q4_K_M", description = "Small CPU bootstrap model that activates Mesh-LLM v0.72.2's plugin-aware API proxy" },
    proxyActivationContextSize = { type = "number", default = default_proxy_activation_context_size, description = "Bounded context size for the CPU proxy-activation model" },
    apiPort = { type = "port", default = default_api_port, description = "Loopback OpenAI-compatible Mesh-LLM API port" },
    consolePort = { type = "port", default = default_console_port, description = "Loopback Mesh-LLM management API port" },
    meshBindAddress = { type = "string", default = "0.0.0.0", description = "Explicit private interface address for Mesh-LLM QUIC transport" },
    meshBindInterface = { type = "nullable_string", default = null, description = "Interface whose global IPv4 address is resolved when the service starts" },
    meshPort = { type = "port", default = default_mesh_port, description = "Fixed UDP port for private Mesh-LLM QUIC transport" },
    meshName = { type = "string", default = "onix-private-inference", description = "Friendly private mesh name" },
    nodeName = { type = "nullable_string", default = null, description = "Optional Mesh-LLM node display name; defaults to the machine hostname" },
    backendUnit = { type = "nullable_string", default = null, description = "Optional local inference systemd unit ordered before the sidecar" },
    backendExternallyManaged = { type = "bool", default = false, description = "Declare that an external owner provides the loopback inference backend" },
  },
}
