# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: Exact ttWKV7 data-movement diagnostic

r[onix.tenstorrent.native_runtime.ttwkv7.data_movement_diagnostic] Onix MUST provide a device-free validated ttWKV7 diagnostic boundary that uses exact production readers and writer without WKV compute, compares deterministic bf16-tagged layouts exactly, fixes a later physical launch to device 1 and one immutable mode, and forbids caller-controlled suffixes, alternate commands, fallback, or retry.

#### Scenario: Pure layout oracles pass
- GIVEN deterministic tags for every reviewed input, state, output, and sentinel position
- WHEN device-free self-tests compare exact expected reader streams and writer matrices
- THEN all positive fixtures pass and row/column transpose, tile permutation, duplicate/drop, wrong-scatter, and sentinel-overwrite fixtures fail

#### Scenario: Production data paths are isolated from compute
- GIVEN the pinned chunked reader, decodeL reader, and writer kernels
- WHEN the diagnostic workloads are constructed
- THEN reader capture drains circular buffer 21 directly, writer scatter feeds circular buffer 16 directly, and no compute kernel is created

#### Scenario: Data-movement kernels are architecture checked
- GIVEN pinned Blackhole and Wormhole RISCV data-movement compiler configurations
- WHEN the offline architecture check runs
- THEN both minimal peer kernels compile for both architectures without enumerating or initializing a device

#### Scenario: Runtime state or dispatch is unsafe
- GIVEN missing or non-exact device-1 visibility, unsafe cache/log paths, a non-loopback Inspector address, an invalid mode, a suffix argument, a mutable target, or an altered dispatch vector
- WHEN the production wrapper is checked or invoked
- THEN it fails before target execution or device access

#### Scenario: One later physical comparison is complete
- GIVEN a separately committed one-shot and explicit authorization for exactly one device-1 data-movement process
- WHEN the immutable diagnostic executes
- THEN it records exactly one result for each reader/path and writer/path combination, one aggregate marker, raw status, invocation count one, and healthy independent owner restoration

#### Scenario: Physical output is incomplete or mismatched
- GIVEN a nonzero mismatch, missing or duplicate record, nonzero status, timeout, initialization failure, isolation failure, or orchestration failure
- WHEN evidence is classified
- THEN the result is narrow and terminal for that authorization and no retry, direct-runtime command, alternate probe, or broader compatibility claim is permitted
