## ADDED Requirements

### Requirement: Settings contract registry maps module-role pairs to contracts

The system SHALL maintain a registry in `inventory/services/settings-contracts.ncl` that maps `(module-name, role-name)` pairs to Nickel record contracts. Each contract specifies the expected field names and their types for that role's settings.

#### Scenario: Registry contains contracts for all services with settings
- **WHEN** a service instance in `services.ncl` has a `settings` record in any role
- **THEN** the registry SHALL have a matching entry keyed by `(module-name, role-name)`

#### Scenario: Registry is importable from contracts.ncl
- **WHEN** `contracts.ncl` imports `settings-contracts.ncl`
- **THEN** the registry SHALL be available as a record for use in validation

### Requirement: Known settings fields are type-checked at ncl export time

Each contract in the registry SHALL specify types for known settings fields. When `ncl export inventory/services/services.ncl` runs, settings values SHALL be checked against these types.

#### Scenario: Correct settings pass validation
- **WHEN** a service instance has `settings.port = 9090` and the contract specifies `port | Number`
- **THEN** `ncl export` SHALL succeed without errors

#### Scenario: Type mismatch is caught
- **WHEN** a service instance has `settings.port = "9090"` and the contract specifies `port | Number`
- **THEN** `ncl export` SHALL fail with an error message identifying the instance, role, and field

#### Scenario: Wrong boolean type is caught
- **WHEN** a service instance has `settings.enableSSH = "yes"` and the contract specifies `enableSSH | Bool`
- **THEN** `ncl export` SHALL fail with an error identifying the type mismatch

### Requirement: Contracts use open records to allow extra fields

Settings contracts SHALL use open record syntax (`..`) so that fields not listed in the contract pass through without error. This allows NixOS module defaults and pass-through config to work.

#### Scenario: Extra settings field passes validation
- **WHEN** a service instance has `settings.customField = "value"` and the contract does not list `customField`
- **THEN** `ncl export` SHALL succeed — the extra field is not rejected

#### Scenario: Contracted field coexists with extra fields
- **WHEN** a service instance has `settings = { port = 8080, customThing = true }` and the contract specifies `port | Number` with open record
- **THEN** `ncl export` SHALL validate `port` as Number and pass `customThing` through

### Requirement: Validation is wired into the existing ValidateRefs pipeline

Settings validation SHALL execute as part of the `| ValidateRefs` contract applied at the bottom of `services.ncl`. The `extra_role_errors` callback in `mkRefValidator` SHALL check settings against the registry.

#### Scenario: Settings errors reported alongside ref errors
- **WHEN** a service instance has both a typo in a tag reference AND a type error in settings
- **THEN** `ncl export` SHALL report both errors (tag ref error and settings type error)

#### Scenario: Services without settings skip validation
- **WHEN** a service instance role has no `settings` field
- **THEN** the settings validator SHALL produce no errors for that role

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
