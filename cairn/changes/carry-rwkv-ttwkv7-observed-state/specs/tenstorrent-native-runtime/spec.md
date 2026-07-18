## ADDED Requirements

### Requirement: The exact physical WKV post-state can seed a device-free next recurrent layer step

The repository SHALL provide a deterministic replay with the sole invocation vector `--evidence-root PATH` that consumes the accepted exact physical second-token WKV post-state together with the corresponding host-owned layer-zero state and completes one subsequent layer-zero token through a CPU WKV recurrence with explicit BF16 transport emulation. The replay SHALL preserve the accepted same-token observed-layer receipt unchanged, keep the enclosing hardware session classified `unsafe`, identify source-FP32, expected-BF16, observed-physical-state, reset-state, and transposed-state paths independently, fingerprint every complete vector, and reject evidence or invocation drift. A passing replay SHALL establish only that the physical post-state is structurally consumable by the shared CPU recurrence and layer suffix; it SHALL NOT claim a physical next-step WKV execution, a wholly device-executed layer, all-layer state carry, token generation, serving, throughput, or latency.

r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]

#### Scenario: Exact physical state advances through one CPU continuation

- **GIVEN** the accepted package-owned unsafe-session evidence, pinned checkpoint, and canonical same-token replay receipt
- **WHEN** the fixed-invocation state-carry replay loads the package-owned accepted evidence and pinned checkpoint
- **THEN** it validates the immutable unsafe classification and prior same-token observed-layer receipt authority
- **AND** it uses token ID `2` as the next layer-zero input after prefix `[1, 2]`
- **AND** it carries the exact physical matrix post-state plus the observed-composition host attention/channel state
- **AND** it applies BF16 transport emulation before and after the CPU WKV recurrence
- **AND** it completes the shared attention and channel-mix suffix
- **AND** it emits finite complete-vector identities and deviations for source, expected, and observed paths
- **AND** repeated runs emit byte-identical receipts.

#### Scenario: Reset and transposed state remain distinguishable

- **GIVEN** the exact physical matrix post-state and corresponding observed host-owned attention/channel state
- **WHEN** one negative control replaces the physical matrix post-state with zero state while preserving the observed host state and next-step input
- **AND** another negative control transposes each physical per-head matrix while preserving the same host state and input
- **THEN** the complete post-state and final layer output differ from the retained observed-state path by named non-zero floors
- **AND** the retained observed-state result remains closer to the expected BF16 result than to the transposed-state result
- **AND** the receipt records all complete-vector identities and deviations.

#### Scenario: Evidence or invocation drift is rejected

- **GIVEN** the package-owned evidence hashes and sole accepted `--evidence-root PATH` invocation vector
- **WHEN** the physical post-state, unsafe classification, prior observed receipt authority, artifact metadata, or invocation vector differs from the package-owned authority
- **THEN** the replay fails before emitting a success receipt
- **AND** it performs no physical-device or owner-service operation.
