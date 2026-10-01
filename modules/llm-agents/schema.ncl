{
  default = {
    packages = { type = "array_string", default = ["pi"], description = "Package names to install from llm-agents flake" },
    ompResearchTools = { type = "bool", default = false, description = "Install the native arxiv_corpus and laya_decide OMP extension" },
    ompResearchUser = { type = "string", default = "brittonr", description = "Home Manager user receiving the OMP research extension" },
    ompResearchUrl = { type = "string", default = "http://127.0.0.1:7997", description = "Private research-only Mesh-LLM HTTP ingress URL" },
    ompUnderclass = { type = "bool", default = false, description = "Run a loopback Underclass subscription pool and register it as an OMP provider" },
    ompUnderclassRemoteHost = { type = "string", default = "", description = "SSH host whose existing Underclass pool is shared over a local OMP tunnel" },
    ompUnderclassUser = { type = "string", default = "brittonr", description = "Local user receiving the OMP provider and Underclass client/admin credentials" },
    underclassMeshGateway = { type = "bool", default = false, description = "Serve the local Underclass Codex pool to Mesh-LLM through a loopback chat-completions gateway holding the proxy key" },
    underclassMeshPort = { type = "port", default = 18081, description = "Loopback port of the Underclass Mesh-LLM gateway; reference it from the mesh-llm extraEndpoints URL" },
  },
}
