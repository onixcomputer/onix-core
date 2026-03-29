## Context

Service instances in `inventory/services/services.ncl` pass settings records through to NixOS modules. The Nickel-side validation currently covers structural fields (module name, input, tag refs, machine refs) but treats settings as `{ _ : Dyn }`. Errors in settings values surface only at NixOS evaluation time, which is slow and produces opaque error messages.

The existing contract system (`contracts.ncl`) already validates machines, tags, and cross-references. The `mkRefValidator` pattern handles per-instance/per-role iteration. The `ServiceInstance` contract enforces `module` shape but leaves `roles` freeform.

Each service module defines its own expected settings — some via `interface.options` (typed mkOption), others via `extendSettings` with `mkDefault` values (freeform). The Nickel contracts mirror the subset of keys that instances actually use, not the full NixOS option space.

## Goals / Non-Goals

**Goals:**
- Validate settings keys and value types at `ncl export` time for all service instances
- Catch typos in setting names (e.g. `enableGPu` vs `enableGPU`)
- Catch type mismatches (e.g. string where number expected, number where bool expected)
- Maintain open records — extra keys pass through to NixOS without blocking
- Keep contracts co-located with the service inventory, not scattered across module directories

**Non-Goals:**
- Full parity with NixOS module option types (no attrsOf submodule, no listOf enum, etc.)
- Validating deeply nested NixOS pass-through settings (e.g. `grafana.settings.server.http_addr` — these are NixOS-native and validated at build time)
- Validating Prometheus rules content (already raw YAML strings, separate concern)
- Enforcing required fields — modules have defaults, Nickel contracts catch shape not completeness

## Decisions

### 1. Single settings-contracts.ncl file with all per-service contracts

Put all service settings contracts in `inventory/services/settings-contracts.ncl`, keyed by `(module-name, role-name)` pairs.

**Why:** Contracts are small (3-10 fields each). A single file keeps them discoverable and diffable. Splitting per-module would create ~20 files with 5-15 lines each.

**Alternative considered:** Per-module .ncl files in `modules/<name>/contracts.ncl`. Rejected because the contracts validate inventory data, not module logic — they belong with the inventory.

### 2. Open-record contracts with typed fields

Each contract specifies the known fields with types. The `..` (open record) marker allows extra fields to pass through. This means:
- Known fields get type-checked
- Unknown fields pass through to NixOS
- Typos on known field names are caught (e.g. `ennableSSH` fails because it's not a known field that matches the Bool contract, but it's allowed as an extra field — however, the *correctly-spelled* field would be missing and noticed by the module)

For fields where typos are the main risk, use closed contracts on the keys that matter most. For pass-through settings blocks (like `grafana.settings`), leave those as `Dyn`.

### 3. Validation wired into existing `ValidateRefs` pipeline

Extend the `extra_role_errors` callback in `mkRefValidator` to also check settings against the contract registry. This keeps validation in the same `| ValidateRefs` pipe at the bottom of `services.ncl`.

**Why:** No new top-level validator needed. The existing pattern handles instance/role iteration. Settings validation is just another check in the same loop.

### 4. Contracts cover the top-level settings keys, not deep NixOS structures

For services like `loki-blr` or `grafana` that pass large nested NixOS config structures, the contract covers the module's own settings keys (e.g. `enablePromtail`, `port`) but leaves NixOS-native config blocks as `Dyn`.

**Why:** Deep NixOS settings are already validated by the module system at build time. Duplicating that validation in Nickel would be high-maintenance and fragile.

### 5. Phased rollout by service group

Implement contracts for service groups in order of risk/frequency of change:
1. Networking services (tailscale, iroh-ssh, cloudflare-tunnel, tailscale-traefik)
2. Monitoring services (prometheus, grafana, loki)
3. LLM/AI services (llm, ollama, llamacpp-rpc, llm-agents)
4. Web services (homepage-dashboard, static-server, vaultwarden, harmonia, buildbot, calibre-server)
5. Infrastructure services (nix-gc, borgbackup, syncthing, sshd, users, home-manager-profiles)
6. Media services (upmpdcli)

This order reflects change frequency and typo risk.

## Risks / Trade-offs

**[Open records dilute typo detection]** → Open records let unknown keys through. A typo on a non-contracted field won't be caught. Mitigation: contract the fields that matter most (the ones actually used in services.ncl instances). Over time, extend coverage.

**[Contract drift from module changes]** → If a module adds/renames a setting, the contract needs updating. Mitigation: contracts are in one file, easy to grep. Add a comment in each module pointing to the contract file.

**[False sense of completeness]** → Users might assume all settings are validated when only top-level keys are. Mitigation: document clearly in contracts file header that deep NixOS config is validated at build time, not by Nickel.
