## Context

All NixOS machines in the fleet use GNU coreutils and C sudo — the defaults from nixpkgs and srvos. Ubuntu 25.04 switched to uutils-coreutils and sudo-rs as defaults, validating both for production use. NixOS has `security.sudo-rs` as a first-class module and `uutils-coreutils-noprefix` as a drop-in coreutils replacement.

Current sudo configuration:
- srvos sets `security.sudo.execWheelOnly = true`
- britton-desktop overrides with `mkForce false` and adds `extraRules` for bpftrace and chaoscontrol-trace
- PAM: fprintAuth disabled for sudo on britton-desktop
- All admin users are in the `wheel` group

## Goals / Non-Goals

**Goals:**
- Replace GNU coreutils with uutils-coreutils-noprefix on all NixOS machines
- Replace C sudo with sudo-rs on all NixOS machines
- Preserve all existing sudo policy (extraRules, execWheelOnly, PAM)
- Single config location in the `nixos` tag so every machine gets it

**Non-Goals:**
- Replacing findutils, diffutils, or other GNU utilities (separate effort)
- Changing sudo policy or permissions
- Affecting darwin machines
- Replacing coreutils in the Nix build sandbox (nixpkgs stdenv still uses GNU)

## Decisions

**1. Use `environment.systemPackages` for uutils, not an overlay**

uutils-coreutils-noprefix goes into systemPackages at higher priority. An overlay replacing `pkgs.coreutils` would affect every derivation in the closure and break builds that depend on GNU-specific flags. systemPackages only affects the user PATH.

Alternative: `nixpkgs.overlays` replacing coreutils → rejected, too invasive, breaks stdenv.

**2. Use `security.sudo-rs` NixOS module**

NixOS has a dedicated `security.sudo-rs` module that mirrors the `security.sudo` option interface. Enabling it automatically disables C sudo. The module supports `execWheelOnly`, `extraRules`, and PAM integration.

Alternative: Manual package swap without the module → rejected, loses NixOS-level integration (sudoers generation, PAM wiring).

**3. Config lives in `inventory/tags/common/uutils-sudo-rs.nix`, imported by `nixos.nix`**

Keeps the `nixos.nix` tag clean. The new file handles both uutils and sudo-rs so they can be reverted together. Follows the existing pattern of `common/` for shared tag config.

Alternative: Inline in `nixos.nix` → rejected, `nixos.nix` is already 120+ lines.

**4. Keep GNU coreutils in systemPackages as fallback**

GNU coreutils remains available at full path (`/run/current-system/sw/bin/gnu-coreutils-*`) or via `pkgs.coreutils`. Some scripts or Nix build hooks may depend on GNU-specific behavior (e.g., `cp --reflink`, `stat --format`). Having it accessible prevents breakage without polluting PATH.

Alternative: Remove GNU coreutils entirely → rejected, too risky for first deployment.

**5. Migrate britton-desktop extraRules from `security.sudo` to `security.sudo-rs`**

The `security.sudo-rs` module uses the same `extraRules` option schema. The britton-desktop config moves from `security.sudo.extraRules` to `security.sudo-rs.extraRules` and `security.sudo-rs.execWheelOnly` respectively.

## Risks / Trade-offs

**[uutils missing GNU extensions]** → Some scripts may use GNU-specific flags not yet in uutils. Mitigation: GNU coreutils stays installed as fallback. Monitor for breakage and file upstream issues.

**[sudo-rs config compatibility]** → sudo-rs supports most sudoers features but not all (e.g., some PAM module interactions). Mitigation: sudo-rs 0.2.13 covers our use cases (NOPASSWD rules, wheel group, execWheelOnly). The NixOS module generates compatible sudoers.

**[srvos `security.sudo.execWheelOnly` conflict]** → srvos sets options on `security.sudo`, not `security.sudo-rs`. When sudo-rs is enabled, the old `security.sudo` options may be ignored or conflict. Mitigation: Explicitly set `security.sudo-rs.execWheelOnly = true` in our config, overriding whatever srvos does to the old module.

**[Rollback]** → If sudo-rs causes authentication issues on a remote machine, you can't SSH in and fix it (SSH is root, but local console needs working sudo). Mitigation: Deploy to britton-desktop first (local console access), then roll out to remote machines. Root SSH access doesn't depend on sudo.
