## Phase 1: Backend implementation

- [ ] [serial] Extract or share Ollama settings-to-module configuration without duplicating the standalone Ollama policy. r[onix.llm.service.ollama]
- [ ] [serial] Enable the managed Ollama service and model-pull behavior from generic LLM role settings. r[onix.llm.service.ollama]
- [ ] [serial] Honor effective host, port, GPU, package, and model settings for Ollama. r[onix.llm.service.ollama]
- [ ] [serial] Make backend selection exhaustive and reject unimplemented service types. r[onix.llm.service.total]
- [ ] [serial] Derive firewall exposure from the enabled backend and effective bind address. r[onix.llm.service.network]
- [ ] [serial] Preserve the standalone Ollama module and vLLM service compatibility surfaces. r[onix.llm.service.total]

## Phase 2: Validation

- [ ] [serial] Add positive checks for Ollama with models, Ollama without models, and existing vLLM behavior. r[onix.llm.service.validation]
- [ ] [serial] Add negative checks for unsupported backends and inconsistent backend settings. r[onix.llm.service.validation]
- [ ] [serial] Verify loopback and remote-bind firewall outcomes. r[onix.llm.service.network]
- [ ] [serial] Evaluate the deployed `britton-desktop` LLM role and model-pull unit. r[onix.llm.service.validation]
- [ ] [serial] Run focused Nix checks plus Cairn validation and gates. r[onix.llm.service.validation]
