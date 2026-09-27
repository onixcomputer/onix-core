## ADDED Requirements

### Requirement: Shared packages come from onixpkgs

r[onix.packages.onixpkgs] Every NixOS and darwin machine, every DGX devenv machine, and every flake check harness MUST apply the onixpkgs overlay before it resolves a package that onixpkgs provides. onix-core MUST NOT keep a second definition of such a package. Only packages that embed onix-core's machine inventory, patch the private tenstorrent.nix flake, or build against onix-core's Nix fork MAY stay under `pkgs/`.

#### Scenario: Name shared with nixpkgs

- GIVEN a machine that installs `pkgs.sendme`, a name nixpkgs also defines
- WHEN the machine configuration is evaluated
- THEN `pkgs.sendme` MUST be onixpkgs' package, not nixpkgs'

#### Scenario: DGX machine without Clan tags

- GIVEN a DGX devenv machine that imports only `modules/dgx-machine`
- WHEN it evaluates `pkgs.mesh-llm`
- THEN the package MUST come from the onixpkgs overlay

#### Scenario: Module check harness

- GIVEN a flake check that evaluates a service module outside a machine
- WHEN the module refers to `pkgs.<name>` for an onixpkgs package
- THEN the harness package set MUST provide the onixpkgs package

#### Scenario: Inventory-bound package

- GIVEN `dgx-machine`, which bakes onix-core's DGX inventory into its build
- WHEN packages move to onixpkgs
- THEN `dgx-machine` MUST stay in onix-core

### Requirement: The kache wrapper library comes from onixpkgs

r[onix.packages.kache_library] onix-core MUST build its kache rustc wrappers with onixpkgs' `lib.kacheNixRust` and MUST NOT keep its own copy of the library or of its wrapper contract check. onix-core keeps the checks that read its own machine configuration and its changebot example.

#### Scenario: Changebot example

- GIVEN the changebot example evaluated by `kache-nix-rust-changebot-example`
- WHEN it builds the rustc wrapper
- THEN the wrapper MUST come from onixpkgs' `lib.kacheNixRust`
