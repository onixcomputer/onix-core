## ADDED Requirements

### Requirement: Hardware-ready real-weight ttWKV7 boundary harness
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness] Onix MUST provide a deterministic, fail-closed, hardware-ready harness that binds the exact accepted real-weight BF16 boundary to one future production ttWKV7 DecodeL workload without performing or authorizing device execution during package validation.

#### Scenario: Exact fixture is prepared before device creation
- GIVEN the accepted 420,072-byte boundary fixture
- WHEN fixture self-test, preflight, or device mode parses it
- THEN the exact whole-file, ordered-artifact, shape, order, byte, and per-artifact authorities are validated before any device creation statement is reachable
- AND another fixture, malformed bytes, changed metadata, missing argument, or extra suffix returns nonzero without a passing receipt

#### Scenario: Fixture mode shares production execution
- GIVEN exact `[a,w,k,v,r,b]` vectors, retained pre-state, and `G=1`, `L=1`, `S=64`, `H=12`
- WHEN the prepared fixture device mode is inspected or eventually invoked
- THEN it uses production's shared host padding, state upload, decode ABI, core partition, circular buffers, reader, compute, writer, workload, and writer extraction path
- AND it does not duplicate the hardware setup in a standalone implementation or modify production kernel sources

#### Scenario: Future workload cardinality is exact
- GIVEN the fixture device mode reaches the production workload shell
- WHEN execution policy is applied
- THEN exactly one workload enqueue is allowed with no warmup, timing loop, retry, fallback, alternate kernel, caller-selected shape, or caller-selected threshold
- AND output storage is deterministically initialized before the workload

#### Scenario: Complete future evidence is preserved
- GIVEN a future authorized workload reaches readback
- WHEN writer results are processed
- THEN the complete raw writer BF16 matrix, all 768 extracted output values, and all 49,152 extracted post-state values are written as separate artifacts
- AND a deterministic manifest and receipt bind fixture, source, runtime-vector, byte-count, BLAKE3, exact-bit-mismatch, PCC, NMSE, maximum-absolute-error, threshold, and non-claim fields

#### Scenario: Numerical decision is fixed before hardware observation
- GIVEN complete finite future output and state evidence
- WHEN the pure comparator classifies it
- THEN passing requires output NMSE and state NMSE each to be less than the fixed `6e-2` ceiling inherited from the reviewed `L=1` production test
- AND failure, timeout, incomplete artifacts, non-finite values, threshold equality, or threshold excess cannot emit the bounded success claim

#### Scenario: Fixture-bearing package is isolated
- GIVEN the ordinary ttWKV7 package and the separate boundary-device harness package
- WHEN runtime closures are inspected
- THEN ordinary ttWKV7 contains no layer harness, checkpoint, safetensor, boundary fixture, or PyTorch path and retains its baseline closure cardinality and existing Metalium Python identity
- AND the separate package exposes one fixed wrapper vector and a valid typed `rwkv-lab` single-process plan naming physical device 1 and explicit restoration evidence

#### Scenario: No-device modes remain no-device
- GIVEN package self-test, runtime preflight, Nix checks, and Cairn validation
- WHEN they run without hardware authorization
- THEN they test exact parsing, host preparation, expected extraction, comparison, receipt construction, wrapper behavior, plan validity, replay, and malformed-input rejection without initializing Metalium, opening a command queue, changing device ownership, or creating an execution lock
- AND source checks reject any fallback from a no-device mode into the device branch

#### Scenario: Existing ttWKV7 boundaries remain stable
- GIVEN the prepared boundary harness
- WHEN package regression checks run
- THEN historical host-layout, decode-reader ABI, checkpoint-shape, synthetic data-movement, aligned-reader, and dual-architecture checks continue to pass
- AND the production reader, compute, and writer kernel identities remain unchanged

#### Scenario: Prepared status is reported narrowly
- GIVEN all device-free harness checks pass
- WHEN integration status is reported
- THEN the claim is limited to deterministic readiness of the exact fixture, production execution path, evidence schema, numerical decision, wrapper, and session plan
- AND no repaired-reader completion, BRISC, NoC, compute, writer, P150, full-layer, full-model, generation, serving, throughput, latency, or hardware authorization claim is inferred
