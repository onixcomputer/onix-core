## ADDED Requirements

### Requirement: Managed Privacy Filter HTTP service
The system MUST provide a managed `privacy-filter` service that runs as a NixOS-managed workload and exposes an HTTP API for privacy detection and redaction requests.

#### Scenario: Service binds configured endpoint
- **WHEN** a `privacy-filter` service instance sets `host` and `port`
- **THEN** the deployed service binds that address and port
- **AND** requests to the configured endpoint are routed to the Privacy Filter runtime

#### Scenario: Local-only endpoint does not open firewall
- **WHEN** a `privacy-filter` service instance binds only `127.0.0.1` or `::1`
- **THEN** the module does not open the service port in the firewall

#### Scenario: Non-local endpoint opens firewall
- **WHEN** a `privacy-filter` service instance binds a non-loopback host
- **THEN** the module opens the configured TCP port in the firewall

### Requirement: Inventory-configurable Privacy Filter settings
The system MUST define a schema-backed `privacy-filter` module whose service settings are validated through the existing Nickel inventory contract flow.

#### Scenario: Defaulted settings validate without overrides
- **WHEN** an inventory service instance omits optional `privacy-filter` settings that have defaults
- **THEN** Nickel export succeeds and the service uses the module defaults

#### Scenario: Invalid setting type is rejected
- **WHEN** an inventory service instance sets a `privacy-filter` setting to a value that does not match the schema type
- **THEN** inventory validation fails during Nickel export with a type error that identifies the setting path

#### Scenario: Module is available in service registry
- **WHEN** `inventory/services/services.ncl` references module `{ name = "privacy-filter", input = "self" }`
- **THEN** module name validation succeeds and the service definition can be instantiated

### Requirement: Runtime can load Hugging Face privacy models on CPU or ROCm hosts
The system MUST let a `privacy-filter` service instance select the model identifier, cache location, and runtime device so the same module can run on CPU-only or AMD GPU machines.

#### Scenario: Aspen deployment uses ROCm-compatible runtime
- **WHEN** a service instance on `aspen1` enables GPU execution
- **THEN** the runtime is configured to use an AMD-compatible device setting rather than an NVIDIA-only path

#### Scenario: CPU deployment remains supported
- **WHEN** a service instance disables GPU execution or selects a CPU device
- **THEN** the runtime starts without requiring GPU devices to be present

#### Scenario: Model cache persists across restarts
- **WHEN** the service downloads `openai/privacy-filter` artifacts into its configured cache directory
- **THEN** those artifacts remain available after service restart and are reused by subsequent starts

### Requirement: Stable request and response contract for redaction callers
The system MUST expose a documented local HTTP contract that accepts text input for privacy analysis and returns structured detection or redaction output suitable for downstream callers.

#### Scenario: Detection request returns structured spans
- **WHEN** a caller submits text for analysis
- **THEN** the service returns machine-readable privacy spans or labels describing the detected sensitive segments

#### Scenario: Redaction request returns transformed text
- **WHEN** a caller requests redaction for an input string
- **THEN** the service returns the redacted text derived from the model output

#### Scenario: Health endpoint reports readiness
- **WHEN** the service runtime has loaded its model and is ready to serve requests
- **THEN** a health or readiness endpoint reports success so systemd and operators can verify service health
