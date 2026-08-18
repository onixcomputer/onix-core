## Context

The existing `tenstorrent` tag declaratively configures TT-KMD, udev rules, eight 1 GiB hugepages for the two detected Blackhole devices, firmware packaging, and diagnostic utilities. The deployed cards identify as two separate p150a boards. Upstream TT-Inference-Server defines `p300` as one dual-die P300 board and does not publish a P150x2 model target, but current TT-Metal and its vLLM worker define `P150x2` as a `(1, 2)` mesh. The pinned `tenstorrent.nix` input ships `p150_x2_mesh_graph_descriptor.textproto`, whose topology declares one two-device Blackhole mesh and four relaxed channels.

Runtime verification on 2026-07-14 confirmed that the packaged `llama-server` opens both physical cards, validates matching logical and physical 1x2 adjacency, and generates VibeThinker-3B Q8_0 tokens through the mesh. Firmware 18.8.0.0 uses TT-Metal's supported single-ERISC compatibility mode, so no firmware mutation was required for this deployment. The mesh generation result establishes healthy topology and execution but not useful llama.cpp model sharding or scaling.

## Decisions

### Decision: Use the pinned native Metalium package boundary

**Choice:** Select `tt-metal` and `llama-cpp-metalium` from `inputs.tenstorrent-nix.packages.${hostSystem}`, install them through the existing host tag, and derive all runtime paths from the selected `tt-metal` store path.

**Rationale:** This keeps source revisions, patches, build inputs, TT-NN bindings, and llama.cpp Metalium support under Nix control. It avoids Ubuntu installer state and does not require an OCI image for the initial native runtime.

### Decision: Declare the linked cards as P150x2

**Choice:** Export `TT_MESH_GRAPH_DESC_PATH` to the shipped `p150_x2_mesh_graph_descriptor.textproto` and export `TT_METAL_HOME` plus `TT_METAL_RUNTIME_ROOT` to the selected Metalium root.

**Rationale:** TT-Metal does not infer multi-card topology reliably under strict initialization. The descriptor matches two separate p150 cards and four logical channels; two connected QSFP-DD cables are expected to provide those channels, subject to runtime health validation.

### Decision: Preserve the manual firmware boundary

**Choice:** Continue packaging firmware declaratively while requiring an explicit operator-reviewed `tt-flash` invocation.

**Rationale:** Firmware flashing mutates hardware and must not occur implicitly during rebuild, activation, or service startup. The runtime configuration can be evaluated before flashing, but hardware execution must confirm compatible firmware first.

### Decision: Do not alias P150x2 to P300

**Choice:** Document that native Metalium uses the P150x2 descriptor and that TT-Inference-Server requires an upstream or reviewed custom P150x2 model specification.

**Rationale:** `p300` is a distinct dual-die board type. Reusing that public device token would bypass hardware/catalog validation and create an unsupported configuration even though both logical meshes contain two chips.

## Risks / Trade-offs

- `tt-metal` and `llama-cpp-metalium` are large derivations and may build locally when no substituter contains them.
- The currently running cards report firmware 18.8.0.0 while the tag packages firmware 19.11.0; TT-Metal falls back to single-ERISC compatibility mode, and any future firmware update remains an explicit manual operation.
- The descriptor establishes the intended topology but does not prove cable health; a Metalium health check must verify all required channels at runtime.
- TT-Inference-Server remains container-oriented and lacks a published P150x2 catalog entry; this change does not claim production vLLM support for the pair.
