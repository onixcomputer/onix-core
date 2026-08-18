# Design: Render Pueue running-task metadata in Herdr

## Context

The desktop profile evaluates typed Nickel data and uses Nix's TOML generator for `herdr/config.toml`. Herdr `0.7.5` supports custom workspace metadata tokens in expanded Space rows.

The separate Pueue plugin publishes `pueue_status`, `pueue_running_1`, and `pueue_running_2`. Missing custom values cause their rows to disappear.

## Goals

- Show a small running-task overview in expanded Herdr Space rows.
- Keep token names and style typed in Nickel.
- Keep all plugin registration and process ownership in Herdr.
- Reject accidental unsafe or unrelated Pueue metadata fields.

## Non-Goals

- Start a monitor or dashboard from Nix activation.
- Install or link the local plugin.
- Store task values in Nix or Nickel.
- Change collapsed or mobile sidebar layouts.

## Decisions

### Decision: Configure three custom rows

**Choice:** Append one styled row for `$pueue_status` and one row for each of `$pueue_running_1` and `$pueue_running_2` after the standard workspace and Git rows.

**Rationale:** Herdr elides missing values, so normal workspaces keep the current compact layout. The plugin controls values; local configuration controls presentation.

### Decision: Require Herdr 0.7.5

**Choice:** Raise the focused compatibility check from `0.7.4` to `0.7.5`.

**Rationale:** The overview depends on the workspace metadata and custom Space row contract in `0.7.5`.

### Decision: Validate safe token names

**Choice:** The focused check requires all three configured custom tokens and rejects a representative environment token.

**Rationale:** This proves the intended view is rendered and guards against expanding the metadata privacy boundary.

### Decision: Preserve runtime ownership

**Choice:** Home Manager continues to render only Herdr configuration. It does not execute the plugin, report metadata, create services, or restart Herdr.

**Rationale:** Herdr and the plugin remain the only runtime owners.

## Test Design

Positive checks inspect the generated TOML for the Herdr version, both action IDs, both keybindings, and all three overview token names.

Negative checks reject an invalid action, the plugin source path, activation mutation, and `$pueue_env`.

## Risks and Trade-offs

- Expanded workspace cards can use three extra lines while the dashboard reports metadata.
- The overview disappears after its plugin-owned expiry. This is safer than stale presentation state.

## Claim Boundary

The Nix check proves only that compatible Herdr configuration contains the intended rows. It does not prove live plugin registration, Pueue daemon health, or current task state.
