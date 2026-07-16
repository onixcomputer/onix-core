## Context

`britton-desktop` serves VibeThinker-3B Q8_0 continuously on physical P150 device 0. Direct `llama-bench` comparisons require exclusive device ownership, so an operator currently stops the root-owned service, runs three nearly identical commands, and remembers to restart it. The latest physical `1x2` run opened both cards successfully and reached about 8.06 decode tokens/s, but the accepted single-device serving path remains about 20 tokens/s. Mesh execution is therefore useful diagnostic evidence, not a justified production replacement.

The Metalium fork parses `GGML_METALIUM_MESH_SHAPE=2x1` into the reported physical `1x2` shape. Each run must use 64 prompt tokens, 32 generated tokens, three repetitions, batch and physical batch size 512, 16 benchmark threads, F16 host KV cache, mmap disabled, flash attention disabled, and trace replay disabled.

## Decisions

### Decision: Keep benchmarking separate from production serving

**Choice:** Add a manually invoked systemd oneshot and operator command instead of enabling llama.cpp mesh aggregation in the VibeThinker server.

**Rationale:** The mesh remains materially slower than the accepted single-card path. A separate oneshot can acquire both cards for bounded diagnostics while preserving the production service configuration and lifecycle contracts.

### Decision: Pair a pure Rust result core with a thin systemd shell

**Choice:** Implement matrix construction, result extraction, topology validation, and summary generation in a tested Rust package. Use a small Nix-generated shell only to record whether VibeThinker was active, stop it, invoke the Rust binary, and restore the prior active state through an exit/signal trap.

**Rationale:** The benchmark data path is deterministic and unit-testable without devices. Service orchestration remains explicit and auditable, while the trap covers ordinary success, command failure, interruption, and termination paths.

### Decision: Isolate every mutable artifact

**Choice:** Run through systemd-managed state, cache, and log directories. Give each matrix case a private cache/log subdirectory and run directory, then publish `latest-summary.json` under the benchmark state directory.

**Rationale:** TT-Metal writes generated Inspector and watcher data relative to runtime paths. Explicit service directories prevent another benchmark from polluting the repository or colliding with production mutable state.

### Decision: Validate the reported topology, not only process success

**Choice:** Require the mesh result to report `Tenstorrent BLACKHOLE 1x2 mesh`, require separate prompt and generation records with the fixed token counts, and reject malformed, incomplete, or wrong-topology output.

**Rationale:** A zero process exit does not prove that both cards opened in the requested orientation or that the expected measurements were emitted.

## Risks / Trade-offs

- Starting the benchmark intentionally interrupts VibeThinker for the duration of the matrix; the command is manual and root-gated.
- SIGKILL or host power loss cannot execute a process trap. VibeThinker remains boot-enabled and can be started normally after such an external failure.
- Device 1 and mesh measurements remain topology diagnostics; they do not imply useful llama.cpp model sharding or production scaling.
