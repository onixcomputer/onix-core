# Design: Single-device topology isolation for ttWKV7

## Context

Tenstorrent-tagged interactive shells export the P150x2 mesh graph descriptor for linked-card workloads. ttWKV7 calls `MeshDevice::create_unit_mesh(0)`. With `TT_VISIBLE_DEVICES=1`, TT-Metal discovers one physical card but still tries to satisfy the inherited two-card graph, producing a strict topology-mapping `TT_FATAL` before any WKV kernel runs.

## Decision

The `wkv7` wrapper will unset `TT_MESH_GRAPH_DESC_PATH` while retaining the pinned `TT_METAL_HOME`, `TT_METAL_RUNTIME_ROOT`, immutable kernel working directory, and any explicit device visibility selected by the operator. This matches the existing single-device Metalium service boundary in `modules/llamacpp-server`, which also clears the host mesh descriptor.

Install checks will assert both sides of the contract: the generated wrapper contains the explicit unset, and it does not export a descriptor value. The existing invalid-mode test remains the no-device negative path.

## Alternatives

- **Pass a one-card descriptor:** Rejected because TT-Metal can discover the selected unit device and a new descriptor would add unnecessary topology maintenance.
- **Remove the host-wide descriptor:** Rejected because linked P150x2 tools intentionally consume it.
- **Require operators to unset the variable manually:** Rejected because the package must remain deterministic across interactive, service, and remote shells.

## Validation

Build the package and layout checks, inspect the generated wrapper contract, deploy a clean committed generation, isolate physical device 1, run one bounded `wkv7 test chunked 1 1`, capture TT-SMI and TT-Metal evidence, and restore the owning inference service regardless of result. Do not automatically retry a failed hardware process.

## Observed Outcome

The corrected run used TT-Metal auto-discovery with no mesh graph descriptor, proving the wrapper topology boundary. Device creation completed and execution reached JIT compilation. The Blackhole compiler then rejected upstream's Wormhole-specific `math::set_addr_mod_base()` call in `wkv7_chunked_compute.cpp`; no WKV kernel executed and P150 compatibility remains unestablished. The owner API recovered, both cards retained healthy DRAM, heartbeats advanced, and no uncorrected GDDR errors or thermal trips appeared.
