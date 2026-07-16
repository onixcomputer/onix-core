## ADDED Requirements

### Requirement: Managed VibeThinker benchmark matrix

r[onix.tenstorrent.model_performance.managed_benchmark] `britton-desktop` SHALL expose a manually invoked, Nix-managed VibeThinker Metalium benchmark that MUST compare physical device 0, physical device 1, and the reported P150x2 `1x2` mesh with fixed inputs and bounded case execution, MUST validate the emitted topology and measurements, MUST isolate all mutable runtime artifacts outside the source repository, and MUST restore VibeThinker plus the card-1 P150 Llama service to their individual prior active states after success or failure.

#### Scenario: Active production services are benchmarked and restored

- GIVEN VibeThinker and the card-1 P150 Llama service are active and the Q8_0 model is present
- WHEN an authorized operator starts the managed benchmark
- THEN the runner stops both device owners before acquiring either P150
- AND it runs the fixed device-0, device-1, and reported `1x2` matrix
- AND it writes validated per-case results plus a summary under its systemd-managed state directory
- AND it restarts both previously active services after the matrix completes

#### Scenario: A production service was already inactive

- GIVEN either VibeThinker or the card-1 P150 Llama service is inactive before the benchmark starts
- WHEN the managed matrix completes
- THEN the runner leaves that previously inactive service inactive
- AND it does not misrepresent an initially inactive service as restored

#### Scenario: Benchmark output is invalid or execution fails

- GIVEN one or both managed P150 services were active before the benchmark
- WHEN a benchmark command fails, times out, emits malformed measurements, or reports the wrong mesh topology
- THEN the managed benchmark exits unsuccessfully with a bounded diagnostic
- AND its cleanup path restarts each previously active managed service
- AND no successful summary replaces the previous accepted result

#### Scenario: Benchmark starts from the source repository

- GIVEN an operator invokes the managed command from an `onix-core` worktree
- WHEN TT-Metal emits cache, Inspector, watcher, or benchmark artifacts
- THEN those artifacts are written only below the benchmark's systemd-managed state, cache, and log directories
- AND the worktree receives no generated runtime directory
