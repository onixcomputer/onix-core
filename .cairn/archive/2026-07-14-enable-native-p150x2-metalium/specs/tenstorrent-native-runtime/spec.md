# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: Native Metalium packages
r[onix.tenstorrent.native_runtime.packages] A Tenstorrent-tagged host SHALL install the pinned native `tt-metal` and `llama-cpp-metalium` packages from the repository's `tenstorrent.nix` input.

#### Scenario: Required packages are present
- GIVEN a host with the `tenstorrent` inventory tag
- WHEN its NixOS system closure is evaluated
- THEN the closure includes both native runtime packages selected from the pinned input

#### Scenario: Required package disappears upstream
- GIVEN a pinned `tenstorrent.nix` package set missing either required package
- WHEN the Tenstorrent tag is evaluated
- THEN evaluation fails with a package-selection error instead of silently omitting native runtime support

### Requirement: P150x2 mesh environment
r[onix.tenstorrent.native_runtime.p150x2_mesh] The Tenstorrent host SHALL export Metalium runtime roots and `TT_MESH_GRAPH_DESC_PATH` for the shipped `p150_x2` descriptor representing one two-device Blackhole mesh with four relaxed channels.

#### Scenario: Native program opens the linked mesh
- GIVEN two p150a cards connected with two QSFP-DD cables and exposed as Tenstorrent device nodes
- WHEN a native Metalium program starts on the configured host
- THEN it receives the Nix-store Metalium root and P150x2 mesh descriptor through the system environment

#### Scenario: Descriptor path is malformed
- GIVEN a configuration whose descriptor filename is absent from the selected `tt-metal` output
- WHEN the native runtime layout check runs
- THEN the check fails before the configuration is treated as deployable

### Requirement: Manual firmware mutation boundary
r[onix.tenstorrent.native_runtime.firmware_boundary] The Tenstorrent configuration MUST NOT flash device firmware automatically during build, activation, boot, or native runtime startup.

#### Scenario: System configuration changes
- GIVEN a newer firmware bundle is packaged by Nix
- WHEN the system is rebuilt or rebooted
- THEN the cards retain their current firmware until an operator explicitly runs the reviewed flash command

#### Scenario: Runtime firmware is incompatible
- GIVEN card firmware that does not satisfy the selected native runtime
- WHEN the operator performs native runtime verification
- THEN verification stops with a compatibility blocker rather than initiating an automatic flash

### Requirement: P150x2 identity remains explicit
r[onix.tenstorrent.native_runtime.identity] Operator documentation MUST identify the linked cards as P150x2 and MUST NOT recommend the TT-Inference-Server `p300` target as an alias for two separate p150 boards.

#### Scenario: Operator follows native instructions
- GIVEN two linked p150a cards
- WHEN the operator reads the generated Tenstorrent host documentation
- THEN the instructions select the P150x2 mesh descriptor and explain the current inference-server catalog limitation

#### Scenario: Operator considers the P300 target
- GIVEN a two-chip `p300` inference-server entry
- WHEN the operator compares it with the installed hardware
- THEN the documentation states that P300 is a distinct dual-die board and does not claim compatibility through naming alone
