# Workstation Tools Specification Delta

## ADDED Requirements

### Requirement: omnibin comes from its pinned input

r[onix.omnibin.source] The `omnibin` and `omnibin-shell` packages MUST come
from the pinned `omnibin` flake input, and that input MUST follow the
repository `nixpkgs`. Adding the input MUST NOT change any existing lock node
other than `root`.

#### Scenario: Only the omnibin lock node is added

r[onix.omnibin.source.single_node]
- GIVEN the lock file before and after the input is added
- WHEN their nodes are compared
- THEN `omnibin` MUST be the only added node
- AND `root` MUST be the only changed node

### Requirement: The omnibin tag installs omnibin

r[onix.omnibin.scope] Machines tagged `omnibin` MUST install `omnibin` and
`omnibin-shell` through the system package list. `britton-desktop` MUST carry
the tag. Machines without the tag MUST NOT install either package.

#### Scenario: The tagged machine installs both packages

r[onix.omnibin.scope.selected]
- GIVEN the evaluated `environment.systemPackages` of `britton-desktop`
- WHEN package names are rendered
- THEN `omnibin` MUST be present
- AND `omnibin-shell` MUST be present

#### Scenario: An untagged machine installs neither

r[onix.omnibin.scope.unselected]
- GIVEN `aspen3`, which is tagged `dev` but not `omnibin`
- WHEN its evaluated package names are rendered
- THEN `omnibin` MUST be absent
- AND `omnibin-shell` MUST be absent

### Requirement: The host store is never replaced

r[onix.omnibin.namespace] The lazy store MUST be mounted only inside the user
and mount namespace that `omnibin-shell` creates. Machines MUST NOT import the
input's NixOS module or define an `omnibin` system service, because that
module mounts a read-only FUSE store over the host's `/nix/store`.

#### Scenario: No system service replaces the store

r[onix.omnibin.namespace.no_service]
- GIVEN the evaluated `britton-desktop` configuration
- WHEN its systemd services are listed
- THEN no `omnibin` service MUST be defined

#### Scenario: The host store is unchanged after a shell

r[onix.omnibin.namespace.host_store]
- GIVEN `omnibin-shell` has run a binary whose store path the host does not
  hold
- WHEN the host's `/nix/store` is inspected afterwards
- THEN that store path MUST still be absent from the host store
- AND the filesystem at `/nix/store` MUST NOT be the omnibin mount

### Requirement: The packaged commands work

r[onix.omnibin.verification] The packaged `omnibin-shell` MUST run an
executable whose store path the host does not hold, and the `omnibin` CLI
MUST resolve executable names from its pinned index.

#### Scenario: A historical interpreter runs

r[onix.omnibin.verification.smoke]
- GIVEN the `python3@3.6.2` store path is absent from the host store
- WHEN `omnibin-shell` runs `python3@3.6.2 --version`
- THEN it MUST report `Python 3.6.2`

#### Scenario: The index resolves names without a mount

r[onix.omnibin.verification.index]
- GIVEN the packaged `omnibin` CLI
- WHEN `omnibin which python3` runs
- THEN it MUST print a `/nix/store/...-python3-.../bin/python3` path
- AND a name no package ever shipped MUST fail to resolve

### Requirement: britton-desktop runs an omnibin-equipped system

r[onix.omnibin.deployment] `britton-desktop` MUST be deployed from the
lineage it already runs. Its closure difference against the running system
MUST be limited to the omnibin packages and their runtime dependencies.

#### Scenario: The deployed PATH resolves both commands

r[onix.omnibin.deployment.path]
- GIVEN the deployed system on `britton-desktop`
- WHEN `omnibin` and `omnibin-shell` are resolved on `PATH`
- THEN both MUST resolve to the packaged executables
