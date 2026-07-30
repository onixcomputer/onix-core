## Context

`onix-core` already installs Herdr from `inputs.llm-agents` and generates `~/.config/herdr/config.toml` from typed Nickel data. The local Pueue plugin remains a separate repository because its Rust dependencies and release lifecycle do not belong in Herdr or `onix-core`.

## Decisions

### 1. Update the existing Herdr provider

**Choice:** Update only the existing `llm-agents` flake input with a Nix lock command, then require the selected Herdr package to be at least `0.7.4`.

**Rationale:** Current `llm-agents` packages Herdr `0.7.5`. Reusing that provider preserves the accepted workstation package boundary and avoids another Herdr input or local package override.

### 2. Keep plugin registration outside activation

**Choice:** Record the trusted local link source in Nickel, but do not run `herdr plugin link` or `herdr plugin install` from Nix or Home Manager activation.

**Rationale:** Herdr owns mutable plugin state. Activation must remain deterministic and must not perform network access, Cargo builds, or live server mutations.

### 3. Generate both Pueue action bindings from typed data

**Choice:** Extend the shared keymap with distinct popup and split chords. Render both plugin actions from the existing Herdr profile shell.

**Rationale:** Popup and tiled use remain equally available. Nickel validates the action IDs and keys before Nix emits TOML.

### 4. Verify package and rendered config together

**Choice:** Add a focused Home Manager check that inspects the selected Herdr package version and generated TOML. Include positive assertions for both action IDs and a negative assertion for an invalid action ID.

**Rationale:** Package compatibility and key configuration form one operator workflow. Testing them together detects stale package pins and malformed bindings before deployment.

## Risks / Trade-offs

- The targeted `llm-agents` update can change other packages exposed by that input.
- The Pueue repository currently has no remote, so initial registration remains a local `herdr plugin link` operation.
- Applying the NixOS generation does not restart an already running Herdr server. The operator must restart it after deployment.
