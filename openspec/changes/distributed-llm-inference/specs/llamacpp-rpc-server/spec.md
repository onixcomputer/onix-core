## ADDED Requirements

### Requirement: RPC worker systemd service
The `worker` role SHALL create a systemd service (`llamacpp-rpc-worker.service`) that runs `rpc-server` from the custom llama.cpp package.

#### Scenario: Worker starts and listens on configured address
- **WHEN** the service starts on aspen2
- **THEN** `rpc-server` listens on the configured bind address and port (default `0.0.0.0:50052`)

#### Scenario: Worker exposes HIP GPU device
- **WHEN** `rpc-server` starts on a machine with ROCm and gfx1151
- **THEN** the server detects and exposes the HIP0 GPU device to RPC clients

#### Scenario: Worker restarts on failure
- **WHEN** the `rpc-server` process crashes
- **THEN** systemd restarts the service after a configurable delay (default 5 seconds)

### Requirement: Worker role configurable options
The `worker` role SHALL expose the following configurable options:
- `bindAddress` (string, default `"0.0.0.0"`)
- `port` (port, default `50052`)
- `enableCache` (bool, default `true`) — enables local tensor cache to avoid re-transfers

#### Scenario: Custom bind address
- **WHEN** `bindAddress` is set to `"10.10.10.2"` and `port` to `50052`
- **THEN** `rpc-server` binds to `10.10.10.2:50052`

#### Scenario: Local cache enabled
- **WHEN** `enableCache` is `true`
- **THEN** `rpc-server` is started with the `-c` flag for local tensor caching

### Requirement: Firewall port opened
The `worker` role SHALL open the configured RPC port in the NixOS firewall.

#### Scenario: Port accessible from main node
- **WHEN** the worker service is active on aspen2
- **THEN** aspen1 can establish a TCP connection to aspen2 on port 50052

### Requirement: Clan service module with perInstance pattern
The module SHALL follow the clan-core perInstance pattern, defined at `modules/llamacpp-rpc/default.nix`, and be registered in `modules/default.nix`.

#### Scenario: Module registered in modules index
- **WHEN** the flake evaluates
- **THEN** `llamacpp-rpc` appears as an available clan service module
