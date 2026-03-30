## ADDED Requirements

### Requirement: Settings contract registry maps module-role pairs to contracts

The system SHALL maintain a registry in `inventory/services/settings-contracts.ncl` that maps `(module-name, role-name)` pairs to Nickel record contracts. Each contract SHALL be auto-generated from the corresponding module's `schema.ncl` file via the `mk_validator` function, rather than hand-maintained as individual field entries.

#### Scenario: Registry contains contracts for all services with settings
- **WHEN** a service module has a `schema.ncl` file with field descriptors for a role
- **THEN** the registry SHALL have a matching entry keyed by `"module-name:role-name"` auto-derived from the schema

#### Scenario: Registry is importable from contracts.ncl
- **WHEN** `contracts.ncl` imports `settings-contracts.ncl`
- **THEN** the registry SHALL be available as a record for use in validation

### Requirement: Known settings fields are type-checked at ncl export time

Each contract in the registry SHALL specify types for known settings fields, derived from the `type` tags in the module's `schema.ncl`. When `ncl export inventory/services/services.ncl` runs, settings values SHALL be checked against these types.

#### Scenario: Correct settings pass validation
- **WHEN** a service instance has `settings.port = 9090` and the schema specifies `port = { type = "port" }`
- **THEN** `ncl export` SHALL succeed without errors

#### Scenario: Type mismatch is caught
- **WHEN** a service instance has `settings.port = "9090"` and the schema specifies `port = { type = "port" }`
- **THEN** `ncl export` SHALL fail with an error message identifying the instance, role, and field

#### Scenario: Wrong boolean type is caught
- **WHEN** a service instance has `settings.enableSSH = "yes"` and the schema specifies `enableSSH = { type = "bool" }`
- **THEN** `ncl export` SHALL fail with an error identifying the type mismatch

### Requirement: Contracts use open records to allow extra fields

Settings contracts SHALL continue to use open record semantics so that fields not listed in the schema pass through without error.

#### Scenario: Extra settings field passes validation
- **WHEN** a service instance has `settings.customField = "value"` and the schema does not include `customField`
- **THEN** `ncl export` SHALL succeed — the extra field is not rejected

#### Scenario: Contracted field coexists with extra fields
- **WHEN** a service instance has `settings = { port = 8080, customThing = true }` and the schema specifies `port = { type = "port" }`
- **THEN** `ncl export` SHALL validate `port` as a port and pass `customThing` through

### Requirement: Validation is wired into the existing ValidateSettings pipeline

Settings validation SHALL continue to execute via the `| ValidateSettings` contract applied at the bottom of `services.ncl`. The `validate_fields` function SHALL use the auto-generated registry to check settings.

#### Scenario: Settings errors reported alongside ref errors
- **WHEN** a service instance has both a typo in a tag reference AND a type error in settings
- **THEN** `ncl export` SHALL report both errors (tag ref error and settings type error)

#### Scenario: Services without settings skip validation
- **WHEN** a service instance role has no `settings` field
- **THEN** the settings validator SHALL produce no errors for that role

### Requirement: Required fields are validated for presence

When a schema field has no `default`, the validator SHALL check that the field is present in the settings. Missing required fields SHALL produce an error at `ncl export` time.

#### Scenario: Required field missing
- **WHEN** a schema declares `domain = { type = "string" }` with no `default` and the service instance omits `settings.domain`
- **THEN** `ncl export` SHALL fail with an error identifying the missing required field and its expected type

#### Scenario: Required field present
- **WHEN** a schema declares `domain = { type = "string" }` with no `default` and the service instance sets `settings.domain = "example.com"`
- **THEN** `ncl export` SHALL succeed

### Requirement: Nested NixOS pass-through settings are typed as Dyn

For services that pass large NixOS config structures (e.g. `grafana.settings.server`, `loki.configuration`), the contract SHALL type those nested blocks as `Dyn` rather than attempting to validate their internal structure.

#### Scenario: Deep NixOS config passes through
- **WHEN** a service instance has `settings.configuration.server.http_listen_port = 3100` and the contract specifies `configuration | Dyn`
- **THEN** `ncl export` SHALL succeed without validating the internal structure of `configuration`

### Requirement: Port numbers use a Port contract

Settings fields representing network ports SHALL use a `Port` contract that validates the value is a number between 1 and 65535.

#### Scenario: Valid port passes
- **WHEN** a settings field has `port = 8080`
- **THEN** the Port contract SHALL accept it

#### Scenario: Port out of range fails
- **WHEN** a settings field has `port = 70000`
- **THEN** `ncl export` SHALL fail with an error identifying the invalid port

#### Scenario: Port zero fails
- **WHEN** a settings field has `port = 0`
- **THEN** `ncl export` SHALL fail with an error identifying the invalid port
