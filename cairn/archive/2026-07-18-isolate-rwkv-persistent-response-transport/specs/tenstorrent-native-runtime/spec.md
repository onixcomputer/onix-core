# Tenstorrent native runtime delta

## ADDED Requirements

### Requirement: Persistent responses use an isolated diagnostic-safe channel

The repository MUST route persistent ttWKV7 response frames through one host-owned channel that is isolated from child stdout and stderr, MUST preserve canonical request/response ABI and one-child session authority, MUST capture both diagnostic streams independently, and MUST fail closed without response-magic scanning, retry, reconnect, fallback, or physical execution during validation. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_response_channel]

#### Scenario: Deliberate stdout noise cannot corrupt a response

- **GIVEN** one persistent child that emits diagnostic bytes on stdout before producing a canonical response
- **WHEN** the host exchanges responses through the dedicated channel
- **THEN** stdout SHALL be preserved as a diagnostic artifact while the response channel SHALL begin at canonical response byte zero and complete all expected frames unchanged

#### Scenario: One response connection spans the session

- **GIVEN** the exact 24-call persistent dispatch sequence
- **WHEN** the host and child establish transport
- **THEN** they SHALL use one response connection across all calls, preserve exact request/response ordering and state continuity, and reject missing, duplicate, stale, shortened, contaminated, or trailing protocol data

#### Scenario: Invalid channel authority fails before device initialization

- **GIVEN** a missing, relative, store-owned, overlong, stale non-socket, or unreachable response path
- **WHEN** the persistent server starts
- **THEN** it SHALL terminate before opening a MeshDevice or executing a workload and SHALL NOT fall back to stdout

#### Scenario: Validation remains device-free

- **GIVEN** CPU fake-server and C++ response-channel fixtures with deliberate diagnostic noise
- **WHEN** Nix, formatting, mutation, closure, and lifecycle checks run
- **THEN** they SHALL validate exact isolated framing without inspecting a board, opening a device, changing owner services, executing a kernel, creating a hardware runbook, or consuming hardware authorization
