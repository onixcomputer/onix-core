## ADDED Requirements

### Requirement: User instances defined in Nickel
The system SHALL define user and home-manager profile instances in `inventory/core/users.ncl`. The file MUST produce the same instance structure as the current `users.nix` when evaluated via `evalNickelFile`.

#### Scenario: Evaluate users.ncl produces expected instances
- **WHEN** `wasm.evalNickelFile ./users.ncl` is called
- **THEN** the result contains instance keys `user-brittonr`, `hm-server`, `hm-laptop`, `hm-desktop` with the same module names, inputs, roles, tags, machine references, and settings (excluding `profilesBasePath`) as the current `users.nix`

### Requirement: Profile name validation
The system SHALL validate home-manager profile names against a known registry. The registry MUST include `base`, `dev`, `noctalia`, `creative`, `social`, `media`.

#### Scenario: Valid profile name passes
- **WHEN** a `home-manager-profiles` instance lists `profiles = ["base", "dev"]`
- **THEN** validation succeeds

#### Scenario: Typo in profile name fails
- **WHEN** a `home-manager-profiles` instance lists `profiles = ["baze", "dev"]`
- **THEN** `ncl export` fails with an error naming the invalid profile

### Requirement: Tag reference validation
The system SHALL validate tag references in user instances against the tag registry in `contracts.ncl`.

#### Scenario: Valid tag reference passes
- **WHEN** a role targets `tags.hm-server = {}`
- **THEN** validation succeeds

#### Scenario: Invalid tag reference fails
- **WHEN** a role targets `tags.hm-serverr = {}`
- **THEN** `ncl export` fails with an error naming the invalid tag

### Requirement: Machine reference validation
The system SHALL validate machine references in user instances against the machine registry in `machines.ncl`.

#### Scenario: Valid machine reference passes
- **WHEN** a role targets `machines.britton-desktop = {}`
- **THEN** validation succeeds

#### Scenario: Invalid machine reference fails
- **WHEN** a role targets `machines.britton-desktoppp = {}`
- **THEN** `ncl export` fails with an error naming the invalid machine

### Requirement: Nix glue injects profilesBasePath
The system SHALL inject `profilesBasePath` into every `home-manager-profiles` instance's settings on the Nix side after evaluating `users.ncl`. The injected path MUST be the Nix path `../home-profiles` relative to the consuming file.

#### Scenario: Evaluated instances have profilesBasePath
- **WHEN** `default.nix` loads `users.ncl` and processes the result
- **THEN** every instance with `module.name = "home-manager-profiles"` has `profilesBasePath` set in its role settings

#### Scenario: Non-profile instances are unmodified
- **WHEN** `default.nix` processes the `user-brittonr` instance
- **THEN** no `profilesBasePath` is injected (it uses the `users` module, not `home-manager-profiles`)
