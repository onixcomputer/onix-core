# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: Deploy bounded RWKV-7 persistent decode observation tools
r[onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation] The `britton-desktop` system SHALL install the package-matched RWKV-7 P150x2 runtime and evidence tools from the pinned `tenstorrent.nix` input so an operator can run a bounded, fail-closed observation for admitted decode windows `[2, 4]`.

#### Scenario: Production observation tools are deployed
- GIVEN a pinned `tenstorrent.nix` revision with the physically admitted P150x2 runtime, monitoring policy, and receipt validator
- WHEN the `britton-desktop` system closure is built and activated
- THEN the runtime and evidence packages are present through stable system paths
- AND the installed profile admits only decode windows `2` and `4`

#### Scenario: Bounded physical telemetry is clean
- GIVEN free physical devices `0` and `1`, inactive competing services, and explicit regular telemetry receipt paths
- WHEN the operator runs one bounded production-selected observation and classifies the complete ordered batch with the installed monitoring policy
- THEN every accepted persistent event reports exact token parity, exact FP32 recurrent-state parity, completed cleanup, no timeout, and no terminal failure
- AND the aggregate monitoring receipt contains no critical or warning alert and recommends retaining current admission

#### Scenario: Observation evidence fails closed
- GIVEN malformed telemetry, duplicate events, parity failure, cleanup failure, replay timeout, terminal failure, unsupported admission, or a missing bounded input
- WHEN the installed monitor classifies the explicit batch
- THEN it returns a nonzero warning, critical, or input-error status with a fixed alert code
- AND no larger decode window becomes admitted
