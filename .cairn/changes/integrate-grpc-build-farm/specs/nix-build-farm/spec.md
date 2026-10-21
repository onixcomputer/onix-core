## ADDED Requirements

### Requirement: Compatible pinned transport

r[onix.build_farm.abi] The gRPC store plugin MUST be compiled against the exact component libraries of the existing pinned Nix fork. Integrating the farm MUST NOT advance unrelated flake inputs.

#### Scenario: Load the fleet plugin

- GIVEN the pinned fleet Nix executable and the packaged plugin
- WHEN Nix opens a gRPC store
- THEN the plugin loads and performs a real store operation without an ABI or version mismatch

### Requirement: Non-recursive shared scheduling

r[onix.build_farm.topology] Aspen1 MUST host the scheduler and balancer, Aspen1 and Aspen2 MUST offer local build capacity, and admitted clients MUST use `aspen1.local:50051`. Workers MUST NOT dispatch builds back to the farm. Independent SSH builders and excluded consumers MUST retain their existing boundaries.

#### Scenario: Build on available workers

- GIVEN admitted clients and two registered workers with matching system features
- WHEN independent derivations are submitted to the farm
- THEN the scheduler assigns work to available workers
- AND completed outputs are retrievable by the clients
- AND neither worker has a remote builder that creates a dispatch cycle

#### Scenario: Worker admission is unavailable

- GIVEN a worker is disconnected or below its configured free-space threshold
- WHEN the scheduler admits new work
- THEN that worker receives no new builds

### Requirement: Authenticated privileged store access

r[onix.build_farm.authentication] Clan MUST generate an offline CA and separate client, worker, and balancer identities. The CA signing key MUST NOT deploy. Build access MUST require an explicitly admitted identity; uncredentialed or unauthorized callers MUST NOT receive trusted store access.

#### Scenario: Admit a managed client

- GIVEN a valid managed client certificate signed by the farm CA
- WHEN the client submits through the authenticated balancer
- THEN the worker authorizes the original client identity and executes the scheduled build

#### Scenario: Deny missing or unlisted identity

- GIVEN a caller without a certificate or with an unlisted certificate identity
- WHEN it requests a build or privileged store operation
- THEN the operation fails without executing that build

### Requirement: Bounded automatic farm publication

r[onix.build_farm.publication] Successful farm outputs MUST publish automatically to the existing isolated Niks3 cache before being advertised as available across workers. Each worker MUST use at most one concurrent upload. Existing maintenance-gated SQLite upload queues MUST remain disabled outside an admitted window.

#### Scenario: Reuse a completed output

- GIVEN a successful farm build
- WHEN another client requests its output from Niks3
- THEN the signed output is available without rebuilding it
- AND automatic farm publication has not activated a maintenance queue

### Requirement: Executable verification evidence

r[onix.build_farm.verification] Verification MUST exercise real gRPC scheduling, output retrieval, and rejected unauthorized access using the pinned runtime, and MUST distinguish isolated evidence from production deployment.

#### Scenario: Integrate without activating live hosts

- GIVEN generated fleet configuration and an isolated runtime smoke
- WHEN the change is delivered
- THEN the evidence states exactly which runtime paths were exercised
- AND it makes no claim of a live fleet deployment unless deployment was actually performed
