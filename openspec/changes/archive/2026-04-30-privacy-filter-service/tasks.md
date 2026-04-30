## 1. Module and schema scaffolding

- [x] 1.1 Create `modules/privacy-filter/` with `default.nix` and `schema.ncl` following the repo's schema-driven clan service module pattern
- [x] 1.2 Register `privacy-filter` in `modules/default.nix` and ensure its schema is picked up by `inventory/services/settings-contracts.ncl` so inventory references and typed settings validate
- [x] 1.3 Add schema-backed settings for bind host/port, model ID, state/cache paths, device or GPU selection, and runtime overrides

## 2. Runtime and service implementation

- [x] 2.1 Implement the Privacy Filter runtime packaging and service wiring needed to load `openai/privacy-filter` and expose detect/redact/health HTTP endpoints
- [x] 2.2 Document the HTTP API contract for detect/redact/health operations, including request bodies, response shapes, readiness semantics, and expected error behavior
- [x] 2.3 Document steady-state operational constraints for cache paths, cache persistence expectations, and CPU/AMD device selection in module readme/comments or equivalent repo docs
- [x] 2.4 Add persistent cache/state directory management and firewall behavior that follows the configured bind address
- [x] 2.5 Ensure the runtime supports both CPU operation and AMD-friendly GPU configuration without depending on NVIDIA-only container flags

## 3. Inventory wiring and verification

- [x] 3.1 Add a `privacy-filter` service instance to `inventory/services/services.ncl` targeting `aspen1` with conservative defaults
- [x] 3.2 Add or update validation/build checks for the new service module and run the relevant before/after test or eval commands
- [x] 3.3 Verify a `privacy-filter` instance with optional settings omitted still passes Nickel export and receives module defaults
- [x] 3.4 Verify loopback vs non-loopback firewall behavior and confirm invalid Nickel setting types are rejected during export/validation
- [x] 3.5 Verify the runtime starts in CPU mode without GPU devices and reuses its cache across restart
- [x] 3.6 Verify the documented detect/redact response schema, readiness contract, and at least one documented error case with local or deployed sample requests; document any operator-facing constraints discovered during rollout
