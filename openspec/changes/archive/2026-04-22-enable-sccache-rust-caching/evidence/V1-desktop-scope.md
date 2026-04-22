Evidence-ID: V1-desktop-scope
Task-ID: V1
Artifact-Type: verification-evidence
Covers: rustcache.desktop-scope.non-desktop

## Commands

```bash
nix eval --impure --json --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; inventory = import ./inventory/core/default.nix { self = flake; }; in inventory.instances.hm-desktop.roles.default.settings.profiles'
```

Output:

```json
["base","dev","noctalia","creative","social","media","sccache"]
```

```bash
nix eval --impure --json --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; inventory = import ./inventory/core/default.nix { self = flake; }; in inventory.instances.hm-server.roles.default.settings.profiles'
```

Output:

```json
["base","dev"]
```

```bash
nix eval --impure --json --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; inventory = import ./inventory/core/default.nix { self = flake; }; in inventory.instances.hm-laptop.roles.default.settings.profiles'
```

Output:

```json
["base","dev","noctalia","social"]
```

## Result

PASS. Evaluated profile lists add `sccache` only to `hm-desktop` (`britton-desktop`). `hm-server` and `hm-laptop` remain unchanged.
