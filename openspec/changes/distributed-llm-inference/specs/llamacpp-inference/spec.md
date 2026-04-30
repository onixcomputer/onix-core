## ADDED Requirements

### Requirement: Inference server systemd service
The `server` role SHALL create a systemd service (`llamacpp-inference.service`) that runs `llama-server` from the custom llama.cpp package with RPC backends and an OpenAI-compatible API.

#### Scenario: Server starts with RPC workers
- **WHEN** the service starts on aspen1 with `rpcWorkers` set to `["10.10.10.2:50052"]`
- **THEN** `llama-server` starts with `--rpc 10.10.10.2:50052` and connects to the remote worker

#### Scenario: Server loads a GGUF model
- **WHEN** `modelPath` is set to `/var/lib/llamacpp/models/qwen3.5-122b-a10b-q8_0.gguf`
- **THEN** `llama-server` loads the model and distributes layers across local and remote GPUs

#### Scenario: Server exposes OpenAI-compatible API
- **WHEN** the service is running
- **THEN** the API endpoint responds to POST requests at `http://<host>:<port>/v1/chat/completions`

#### Scenario: Server restarts on failure
- **WHEN** the `llama-server` process crashes
- **THEN** systemd restarts the service after a configurable delay (default 10 seconds)

### Requirement: Server role configurable options
The `server` role SHALL expose the following configurable options:
- `host` (string, default `"0.0.0.0"`)
- `port` (port, default `8081`)
- `modelPath` (string) — path to the GGUF model file
- `rpcWorkers` (list of strings, default `[]`) — list of `"host:port"` RPC worker addresses
- `gpuLayers` (int, default `999`) — number of layers to offload to GPU (`-ngl`)
- `flashAttention` (bool, default `true`) — enable flash attention (`-fa`)
- `contextSize` (int, default `8192`) — context window size (`-c`)
- `noMmap` (bool, default `true`) — disable mmap for RPC compatibility (`--no-mmap`)
- `extraArgs` (list of strings, default `[]`) — additional llama-server arguments

#### Scenario: All options passed to llama-server
- **WHEN** the service starts with `modelPath`, `rpcWorkers`, `flashAttention`, and `contextSize` configured
- **THEN** the resulting command line includes `-m <modelPath> --rpc <workers> -fa -c <contextSize> -ngl 999 --no-mmap`

### Requirement: Model storage directory
The `server` role SHALL create `/var/lib/llamacpp/models/` with appropriate ownership for storing GGUF model files.

#### Scenario: Directory exists on activation
- **WHEN** the NixOS configuration is activated
- **THEN** `/var/lib/llamacpp/models/` exists and is writable by the service user

### Requirement: Firewall port opened for API
The `server` role SHALL open the configured API port in the NixOS firewall.

#### Scenario: API accessible from network
- **WHEN** the inference server is running on aspen1 port 8081
- **THEN** clients on the local network can reach `http://aspen1:8081/v1/chat/completions`

### Requirement: Service ordering dependency
The `server` role SHALL configure the systemd service to start after network-online.target so the thunderbolt link is available before attempting RPC connections.

#### Scenario: Service waits for network
- **WHEN** the system boots
- **THEN** `llamacpp-inference.service` starts only after `network-online.target` is reached

### Requirement: Inventory wiring with tags
The service instance SHALL be configured in `inventory/services/` with:
- `worker` role mapped to a `llamacpp-worker` tag
- `server` role mapped to a `llamacpp-server` tag
- aspen1 assigned the `llamacpp-server` tag in `inventory/core/machines.ncl`
- aspen2 assigned the `llamacpp-worker` tag in `inventory/core/machines.ncl`
- Both tags registered in `inventory/core/contracts.ncl`

#### Scenario: Tag-based deployment
- **WHEN** aspen1 has the `llamacpp-server` tag and aspen2 has the `llamacpp-worker` tag
- **THEN** building aspen1 includes the inference server service and building aspen2 includes the RPC worker service

#### Scenario: Service instance references workers by thunderbolt IP
- **WHEN** the service instance configures `rpcWorkers` for the server role
- **THEN** the worker address uses the thunderbolt link IP `10.10.10.2:50052`
