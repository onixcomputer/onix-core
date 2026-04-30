## ADDED Requirements

### Requirement: Clan service module with master and worker roles [r[buildbot-clan-service.roles]]
The buildbot module SHALL be a clan service (`_class = "clan.service"`) with two roles: `master` and `worker`. The master role SHALL wrap `buildbot-nix.nixosModules.buildbot-master`. The worker role SHALL wrap `buildbot-nix.nixosModules.buildbot-worker`.

#### Scenario: Module registered in modules/default.nix [r[buildbot-clan-service.roles.registry]]
- **WHEN** the module registry at `modules/default.nix` is evaluated
- **THEN** it SHALL contain a `"buildbot"` entry pointing to `import ./buildbot`

#### Scenario: Master role produces valid NixOS config [r[buildbot-clan-service.roles.master-config]]
- **WHEN** a machine is assigned the `master` role in the inventory
- **THEN** the machine's NixOS configuration SHALL include `services.buildbot-nix.master.enable = true` and all required master options (domain, workersFile, GitHub auth, buildSystems)

#### Scenario: Worker role produces valid NixOS config [r[buildbot-clan-service.roles.worker-config]]
- **WHEN** a machine is assigned the `worker` role in the inventory
- **THEN** the machine's NixOS configuration SHALL include `services.buildbot-nix.worker.enable = true` with `workerPasswordFile` pointing to the clan vars generated password

### Requirement: Master role manages all secrets via clan vars generators [r[buildbot-clan-service.secrets]]
The master role's perInstance SHALL define clan vars generators for all buildbot secrets. Generator names SHALL be `buildbot-worker` (for password + workers JSON) and `buildbot-github` (for OAuth secret, webhook secret, and App secret key).

#### Scenario: Worker password and workers JSON generation [r[buildbot-clan-service.secrets.worker-json]]
- **WHEN** the master role perInstance is applied
- **THEN** a clan vars generator named `buildbot-worker` SHALL exist that produces `password` and `workers` files, where `password` is 32 bytes of random base64 and `workers` is a JSON array with worker name, password, and core count

#### Scenario: GitHub secrets generation [r[buildbot-clan-service.secrets.github]]
- **WHEN** the master role perInstance is applied
- **THEN** a clan vars generator named `buildbot-github` SHALL exist with prompted files for `oauth-secret`, `webhook-secret`, and `app-secret-key`

#### Scenario: Generator names match existing vars [r[buildbot-clan-service.secrets.names]]
- **WHEN** existing SOPS-encrypted vars exist under `vars/per-machine/aspen1/buildbot-worker/` and `vars/per-machine/aspen1/buildbot-github/`
- **THEN** the module's generators SHALL use the exact same names so no secret re-generation is needed

### Requirement: Settings interface with freeform passthrough [r[buildbot-clan-service.settings]]
Both roles SHALL accept a `freeformType = attrsOf anything` interface. Named options SHALL be provided for commonly-used settings. Unrecognized settings SHALL pass through to the underlying `services.buildbot-nix.master` or `services.buildbot-nix.worker` options.

#### Scenario: Master high-level settings [r[buildbot-clan-service.settings.master]]
- **WHEN** the master inventory settings include `domain`, `buildSystems`, `admins`, `evalWorkerCount`, `evalMaxMemorySize`, `outputsPath`, or `postBuildSteps`
- **THEN** these SHALL map to the corresponding `services.buildbot-nix.master.*` options

#### Scenario: Freeform passthrough for master [r[buildbot-clan-service.settings.master-freeform]]
- **WHEN** the master inventory settings include an attr not covered by a named option (e.g., `failedBuildReportLimit`)
- **THEN** it SHALL be passed through to `services.buildbot-nix.master` via freeform

#### Scenario: Worker high-level settings [r[buildbot-clan-service.settings.worker]]
- **WHEN** the worker inventory settings include `workers`
- **THEN** it SHALL map to `services.buildbot-nix.worker.workers`

### Requirement: Inventory service instance replaces direct import [r[buildbot-clan-service.inventory]]
An inventory service instance SHALL exist at `inventory/services/buildbot.nix` that assigns the master role to aspen1 and the worker role to aspen1. The direct import in `machines/aspen1/configuration.nix` SHALL be removed.

#### Scenario: Inventory instance defines master on aspen1 [r[buildbot-clan-service.inventory.master]]
- **WHEN** the inventory is evaluated
- **THEN** the buildbot service instance SHALL assign `roles.master.machines."aspen1"` with settings for domain, GitHub app config, buildSystems, eval settings, outputsPath, postBuildSteps, and admins

#### Scenario: Inventory instance defines worker on aspen1 [r[buildbot-clan-service.inventory.worker]]
- **WHEN** the inventory is evaluated
- **THEN** the buildbot service instance SHALL assign `roles.worker.machines."aspen1"` with `workers = 16`

#### Scenario: machines/aspen1/buildbot.nix is removed [r[buildbot-clan-service.inventory.direct-import-removed]]
- **WHEN** the change is complete
- **THEN** `machines/aspen1/buildbot.nix` SHALL NOT exist and `machines/aspen1/configuration.nix` SHALL NOT import it

### Requirement: Functional parity with existing config [r[buildbot-clan-service.parity]]
The resulting NixOS configuration for aspen1 SHALL be functionally identical to the current `machines/aspen1/buildbot.nix`. This includes the ntfy notification postBuildStep, outputsPath, firewall rules, tmpfiles rules, and all GitHub auth settings.

#### Scenario: ntfy notification on build failure [r[buildbot-clan-service.parity.ntfy]]
- **WHEN** a build fails on the buildbot master
- **THEN** the postBuildStep SHALL send an ntfy notification with title, priority, and tags matching the current implementation

#### Scenario: Output store paths written for update-prefetch [r[buildbot-clan-service.parity.outputs-path]]
- **WHEN** a build succeeds
- **THEN** the outputsPath SHALL be set to `/var/www/buildbot/nix-outputs/` and the tmpfiles rule SHALL create that directory owned by buildbot

#### Scenario: Firewall opens port 80 [r[buildbot-clan-service.parity.firewall]]
- **WHEN** the master role is applied
- **THEN** `networking.firewall.allowedTCPPorts` SHALL include port 80

### Requirement: buildbot-nix imports are contained in the module [r[buildbot-clan-service.imports]]
The buildbot-nix NixOS modules (`buildbot-master`, `buildbot-worker`) SHALL only be imported by machines that are assigned the corresponding roles. The module SHALL receive `inputs` to access `inputs.buildbot-nix.nixosModules.*`.

#### Scenario: Non-buildbot machines don't import buildbot-nix [r[buildbot-clan-service.imports.non-buildbot]]
- **WHEN** a machine has no buildbot roles assigned
- **THEN** its NixOS configuration SHALL NOT include any buildbot-nix modules

#### Scenario: Module receives inputs for buildbot-nix access [r[buildbot-clan-service.imports.inputs]]
- **WHEN** the module is loaded via `modules/default.nix`
- **THEN** it SHALL receive `inputs` as a parameter and use `inputs.buildbot-nix.nixosModules.buildbot-master` and `inputs.buildbot-nix.nixosModules.buildbot-worker` in the respective role perInstance nixosModules
