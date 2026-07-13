## Why

Aspen1 and `britton-desktop` already expose distinct local OpenAI-compatible inference services on `127.0.0.1:13305`, but there is no shared routing layer that presents both model inventories through one endpoint. Mesh-LLM can provide that layer as a CPU-only sidecar without replacing Lemonade, llama.cpp, or Aspen1's Aspen2 RPC worker.

## What Changes

- Package the upstream Mesh-LLM v0.72.2 Linux CPU bundle and openai-endpoint v0.1.2 plugin for NixOS.
- Add a schema-driven Clan service that runs a headless Mesh-LLM sidecar against a local OpenAI-compatible endpoint and bounds the small CPU model required to activate v0.72.2's plugin-aware proxy.
- Keep HTTP API and management listeners loopback-only while allowing a fixed private mesh QUIC port on an explicitly selected host address.
- Bootstrap Aspen1 as the private seed, capture its runtime invite token into a Clan-managed secret, and join `britton-desktop` with that credential.
- Assign the service only to Aspen1 and `britton-desktop`; do not change Aspen2 or Aspen3.
- Add focused positive and negative evaluation checks for service wiring, secret handling, listener exposure, and assignment scope.

## Impact

- **Files**: `pkgs/mesh-llm/`, `modules/mesh-llm/`, package/module registries, shared package overlay, service inventory, focused flake checks, and Cairn lifecycle artifacts.
- **Runtime**: Adds one CPU-only sidecar process and one external-endpoint plugin process on each selected node. A 512-token Qwen3 0.6B compatibility model activates v0.72.2's plugin-aware proxy without GPU access; existing inference services and Aspen1→Aspen2 llama.cpp RPC remain authoritative.
- **Security**: The mesh uses LAN-only mDNS transport, no public publication, no Nostr relay discovery, loopback-only HTTP listeners, and a Clan-managed join credential. The upstream CLI requires the invite token in `--join`, so it is transiently visible to privileged process inspection but never enters the Nix store.
- **Testing**: Build the package, validate Nickel inventory, evaluate focused module checks and selected machine configurations, validate Cairn gates, then deploy and probe both live nodes.
