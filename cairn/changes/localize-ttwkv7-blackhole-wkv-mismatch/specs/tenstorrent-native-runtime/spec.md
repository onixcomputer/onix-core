## ADDED Requirements

### Requirement: ttWKV7 exact cross-kernel diagnostic
r[onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic] Onix MUST provide a device-free validated diagnostic boundary that accepts only reviewed writable Metalium runtime state and, after separate physical authorization, executes the immutable packaged ttWKV7 runtime with exactly `test all 1 1` in one process without caller-controlled kernel, shape, tolerance, target, suffix, fallback, or retry.

#### Scenario: Exact diagnostic dispatch is validated without a device
- GIVEN a fake executable target and valid temporary cache, log, and loopback Inspector state
- WHEN package validation invokes diagnostic mode
- THEN the captured argument vector is exactly `test`, `all`, `1`, `1` once and in order
- AND package validation does not enumerate, open, reset, or communicate with a Tenstorrent device

#### Scenario: Diagnostic vector is changed
- GIVEN a candidate wrapper or composed package dispatch
- WHEN the target, mode, kernel selector, group count, sequence length, order, multiplicity, or suffix differs from the reviewed vector
- THEN deterministic validation fails before any physical authorization

#### Scenario: Runtime state is unsafe
- GIVEN missing or non-exact device-1 visibility, a missing, relative, Nix-store, non-directory, or unwritable cache or log path, or a non-loopback or invalid Inspector address
- WHEN validation or diagnostic mode is requested
- THEN the wrapper fails before target execution

#### Scenario: Physical comparison is not explicitly authorized
- GIVEN device-free gates pass but no new instruction explicitly authorizes one device-1 cross-kernel diagnostic process
- WHEN implementation reaches the physical boundary
- THEN the owner remains active and no diagnostic process, device initialization, isolation, or invocation-count transition occurs

#### Scenario: One physical comparison is authorized
- GIVEN a fresh committed executable one-shot, exact reviewed store paths, healthy owner, independent restoration, zero counters, and explicit authorization for one device-1 cross-kernel process
- WHEN the one-shot invokes diagnostic mode
- THEN invocation count changes from zero to one immediately before one timeout-bounded outer wrapper process
- AND the process runs the reviewed chunked and decodeL cases without an alternate command or retry

#### Scenario: Cross-kernel evidence is classified
- GIVEN the sole process returns any status or emits partial or complete numerical records
- WHEN the result is classified
- THEN classification uses exact chunked, decodeL, aggregate-result, process-status, restoration, and board evidence
- AND matching failures do not identify a unique shared component
- AND no full-WKV correctness, decode correctness, performance, or general P150 compatibility claim is inferred
