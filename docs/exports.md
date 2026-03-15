# Clan-Core Exports System

Status: upstream marks exports as **"Experimental"** but zerotier, wireguard, mycelium, and data-mesher all use them. The pattern is stable.

Pinned upstream rev: `19ded1316e131ebc339f487b44908921bd96c2bd`

## Scope Keys

Exports are keyed by `"SERVICE:INSTANCE:ROLE:MACHINE"`. Empty segments mean "all".

```
"clan-core/zerotier:homelab:peer:server1"   # specific machine in a role
"clan-core/zerotier:homelab::"              # all machines in instance
"clan-core/zerotier:::"                     # service-wide
```

At least one of `serviceName` or `machineName` must be set. Global `":::"` is not supported.

## Export Interfaces

Five built-in interfaces defined in `modules/clan/top-level-interface.nix`:

| Interface | Module | Purpose |
|-----------|--------|---------|
| `peer` | `export-modules/peer.nix` | SSH connectivity — hostname list, port, user, SSH options |
| `networking` | `export-modules/networking.nix` | Network priority + technology module (direct, tor) |
| `dataMesher` | `export-modules/data-mesher.nix` | Signed file distribution — file names → ed25519 pubkeys |
| `endpoints` | `export-modules/endpoints.nix` | Generic hostname list |
| `generators` | `export-modules/generators.nix` | Cross-generator dependencies |

Services whitelist which interfaces they emit via `manifest.exports.out`:

```nix
manifest.exports.out = [ "networking" "peer" ];
```

## Producing Exports

### From `perInstance`

The `mkExports` helper auto-builds the scope key from the current context:

```nix
roles.peer.perInstance = { mkExports, machine, ... }: {
  exports = mkExports {
    peer.hosts = [{ plain = "${machine.name}.wg"; }];
  };
};
```

`mkExports` wraps the value in `{ "svc:inst:role:machine" = value; }` using `clanLib.buildScopeKey`.

### From `perMachine`

Same pattern, but scope has no role or instance:

```nix
perMachine = { mkExports, machine, ... }: {
  exports = mkExports { endpoints.hosts = [ ... ]; };
};
```

### Service-wide exports

Set directly on the service module (outside roles):

```nix
exports = lib.mapAttrs' (instanceName: _: {
  name = clanLib.buildScopeKey {
    inherit instanceName;
    serviceName = config.manifest.name;
  };
  value = { networking.priority = 900; };
}) config.instances;
```

## Consuming Exports

The full `exports` attrset is passed as a specialArg to `perInstance` and `perMachine`. It contains scope-keyed entries from **all** services, not just the current one.

```nix
perInstance = { exports, ... }:
let
  allExports = lib.attrValues exports;
  # extract dataMesher.files from every service that exports them
  exportedFiles = lib.foldl' (acc: ev:
    let files = if ev ? dataMesher && ev.dataMesher != null then ev.dataMesher.files else {};
    in lib.foldlAttrs (a: name: keys: a // { ${name} = (a.${name} or []) ++ keys; }) acc files
  ) {} allExports;
in { ... };
```

### Helpers (`clanLib`)

| Function | Signature | Use |
|----------|-----------|-----|
| `buildScopeKey` | `{ serviceName?; instanceName?; roleName?; machineName?; }` → `str` | Build a scope key |
| `parseScope` | `str` → `{ serviceName; instanceName; roleName; machineName; }` | Parse a scope key |
| `selectExports` | `(scope → bool)` → `exports` → `exports` | Filter by predicate on parsed scope |
| `getExport` | `{ serviceName?; ... }` → `exports` → `value` | Get single export (throws if missing) |
| `checkExports` | constraint → exports → exports | Validate scope correctness |
| `checkScope` | constraint → scopeKey → scopeKey | Validate single scope key |

Filtering example:

```nix
prometheusExports = clanLib.selectExports
  (scope: scope.serviceName == "prometheus")
  exports;
```

## Our Modules — Current State

None of our modules produce or consume exports. All cross-service wiring uses explicit configuration.

### Candidates for export adoption

| Module | Would produce | Would consume |
|--------|--------------|---------------|
| `prometheus` | `endpoints` (scrape targets) | Other services' endpoints for auto-scrape |
| `grafana` | `endpoints` (dashboard URL) | Prometheus/loki endpoints for data sources |
| `loki` | `endpoints` (push API) | — |
| `cloudflare-tunnel` | — | `endpoints` for auto-ingress |
| `homepage-dashboard` | — | `endpoints` for service discovery |
| `vaultwarden` | `endpoints` | — |
| `ollama` / `llm` | `endpoints` | — |

## Upstream Examples

### Zerotier (producer)

```nix
# clanServices/zerotier/default.nix
manifest.exports.out = [ "networking" "peer" ];

# service-wide: networking priority
exports = lib.mapAttrs' (instanceName: _: {
  name = clanLib.buildScopeKey { inherit instanceName; serviceName = config.manifest.name; };
  value = { networking.priority = 900; };
}) config.instances;

# per-instance: peer host via vars
roles.peer.perInstance = { mkExports, machine, ... }: {
  exports = mkExports {
    peer.hosts = [{
      plain = clanLib.getPublicValue {
        machine = machine.name;
        generator = "zerotier";
        file = "zerotier-ip";
        flake = directory;
      };
    }];
  };
};
```

### Data-mesher (consumer)

```nix
# clanServices/data-mesher/default.nix
roles.default.perInstance = { exports, settings, ... }:
let
  allExports = lib.attrValues exports;
  exportedFiles = lib.foldl' (acc: ev:
    let files = if ev ? dataMesher && ev.dataMesher != null then ev.dataMesher.files else {};
    in lib.foldlAttrs (a: n: keys: a // { ${n} = (a.${n} or []) ++ keys; }) acc files
  ) {} allExports;
  mergedFiles = lib.foldlAttrs (acc: n: keys:
    acc // { ${n} = (acc.${n} or []) ++ keys; }
  ) exportedFiles settings.network.files;
in { ... };
```

## Flow Summary

```
Service A (perInstance)              Service B (perInstance)
  │                                    │
  ├─ mkExports { peer.hosts = ... }    ├─ mkExports { endpoints.hosts = ... }
  │                                    │
  └──────────┐         ┌───────────────┘
             ▼         ▼
        exports (scope-keyed attrset)
        {
          "svcA:i1:peer:m1" = { peer = ...; };
          "svcB:i2:default:m2" = { endpoints = ...; };
        }
             │         │
             ▼         ▼
  Service C (perInstance)
    │
    ├─ { exports, ... }:
    │    selectExports (s: s.serviceName == "svcB") exports
    │    → auto-discover svcB endpoints
    │
    └─ nixosModule = ...
```
