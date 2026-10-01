{
  default = {
    packages = { type = "array_string", default = ["pi"], description = "Package names to install from llm-agents flake" },
    ompResearchTools = { type = "bool", default = false, description = "Install the native arxiv_corpus and laya_decide OMP extension" },
    ompResearchUser = { type = "string", default = "brittonr", description = "Home Manager user receiving the OMP research extension" },
    ompResearchUrl = { type = "string", default = "http://127.0.0.1:7997", description = "Private research-only Mesh-LLM HTTP ingress URL" },
  },
}
