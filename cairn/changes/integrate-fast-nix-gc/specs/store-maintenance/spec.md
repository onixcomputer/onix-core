# store-maintenance Specification

## Purpose

Define fast, duplicate-free Nix store garbage collection and optimization for Onix NixOS machines using the existing `store-maintenance` service surface.

## Requirements

### Requirement: Upstream fast-nix-gc dependency

r[onix.store.fast_gc.dependency] The system MUST declare Mic92's `fast-nix-gc` as a flake input and use that input as the source of the fast garbage collector module and package.

#### Scenario: Dependency is available to service modules

r[onix.store.fast_gc.dependency.available]
- GIVEN the flake is evaluated
- WHEN the `nix-gc` service module is imported
- THEN the module can reference `inputs.fast-nix-gc.nixosModules.default`

### Requirement: Fast module integration

r[onix.store.fast_gc.module] The `nix-gc` clan service MUST import the upstream fast-nix-gc NixOS module for NixOS store-maintenance instances.

#### Scenario: Service options exist

r[onix.store.fast_gc.module.options]
- GIVEN a NixOS machine has the `store-maintenance` service role
- WHEN its configuration is evaluated
- THEN `services.fast-nix-gc` options are declared
- AND `services.fast-nix-optimise` options are declared

### Requirement: Fast garbage collection

r[onix.store.fast_gc.gc] The system MUST render automatic `services.fast-nix-gc` settings from the existing store-maintenance retention and schedule settings when fast GC is enabled.

#### Scenario: Default retention renders

r[onix.store.fast_gc.gc.default_retention]
- GIVEN store-maintenance uses the default retention period
- WHEN the NixOS configuration is evaluated
- THEN `services.fast-nix-gc.deleteOlderThan` is the retention period suffixed with `d`
- AND `services.fast-nix-gc.automatic` is enabled

### Requirement: Fast store optimization

r[onix.store.fast_gc.optimise] The system MUST render automatic `services.fast-nix-optimise` settings from the existing optimization settings when fast GC is enabled.

#### Scenario: Optimization schedule renders

r[onix.store.fast_gc.optimise.schedule]
- GIVEN `optimizeStore` is enabled
- WHEN the NixOS configuration is evaluated
- THEN `services.fast-nix-optimise.enable` is enabled
- AND `services.fast-nix-optimise.automatic` is enabled
- AND `services.fast-nix-optimise.dates` follows `optimizeSchedule`

### Requirement: No duplicate scheduled collectors

r[onix.store.fast_gc.no_duplicates] The system MUST disable stock scheduled `nix.gc` and `nix.optimise` timers when the fast path is enabled.

#### Scenario: Fast path disables stock timers

r[onix.store.fast_gc.no_duplicates.fast]
- GIVEN `useFastGc` is enabled
- WHEN the NixOS configuration is evaluated
- THEN `nix.gc.automatic` is disabled
- AND `nix.optimise.automatic` is disabled

### Requirement: Stock fallback

r[onix.store.fast_gc.fallback] The system MUST retain a settings fallback that renders the previous stock Nix GC and optimization timers.

#### Scenario: Fast path disabled

r[onix.store.fast_gc.fallback.stock]
- GIVEN `useFastGc` is disabled
- WHEN the NixOS configuration is evaluated
- THEN stock `nix.gc.automatic` is enabled
- AND stock `nix.gc.options` includes the retention period
- AND stock `nix.optimise.automatic` follows `optimizeStore`

### Requirement: Fast GC tuning

r[onix.store.fast_gc.tuning] The system SHOULD expose fast-nix-gc tuning fields for free-space targets, recent-path preservation, vacuum behavior, extra root directories, and extra CLI arguments.

#### Scenario: Optional tuning is unset

r[onix.store.fast_gc.tuning.unset]
- GIVEN no optional tuning fields are configured
- WHEN the NixOS configuration is evaluated
- THEN the upstream fast-nix-gc defaults apply for those fields

#### Scenario: Optional tuning is configured

r[onix.store.fast_gc.tuning.configured]
- GIVEN optional fast-nix-gc tuning fields are configured
- WHEN the NixOS configuration is evaluated
- THEN the corresponding `services.fast-nix-gc` options receive those values

### Requirement: Tag-specific retention overrides

r[onix.store.fast_gc.tag_overrides] The system MUST preserve known tag-specific retention and schedule overrides after switching to fast-nix-gc.

#### Scenario: Boot partition GC stays stricter

r[onix.store.fast_gc.tag_overrides.boot]
- GIVEN a machine uses the boot-partition GC tag
- WHEN the NixOS configuration is evaluated
- THEN fast-nix-gc uses the stricter boot-partition retention period

#### Scenario: Cloud guest GC stays aggressive

r[onix.store.fast_gc.tag_overrides.guest]
- GIVEN a machine uses the cloud-hypervisor guest tag
- WHEN the NixOS configuration is evaluated
- THEN fast-nix-gc uses the daily aggressive guest retention schedule

### Requirement: Build-time auto optimization remains separate

r[onix.store.fast_gc.auto_optimise] The system MUST keep `nix.settings.auto-optimise-store` controlled by the existing `autoOptimise` setting independently of scheduled fast optimization.

#### Scenario: Auto optimize remains configured

r[onix.store.fast_gc.auto_optimise.setting]
- GIVEN `autoOptimise` is enabled
- WHEN the NixOS configuration is evaluated
- THEN `nix.settings.auto-optimise-store` is enabled

### Requirement: Positive and negative verification

r[onix.store.fast_gc.verification] The system MUST include validation evidence for both enabled fast GC settings and the disabled fallback path.

#### Scenario: Fast path validates

r[onix.store.fast_gc.verification.fast]
- GIVEN the default store-maintenance settings
- WHEN focused validation runs
- THEN the fast GC configuration evaluates successfully

#### Scenario: Fallback path validates

r[onix.store.fast_gc.verification.fallback]
- GIVEN `useFastGc` is disabled
- WHEN focused validation runs
- THEN the stock GC fallback configuration evaluates successfully
