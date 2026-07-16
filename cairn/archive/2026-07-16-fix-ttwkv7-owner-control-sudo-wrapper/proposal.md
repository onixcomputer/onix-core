# Change: Use the NixOS sudo wrapper for ttWKV7 owner control

## Why

Activation of the reviewed owner-control capability exposed that `${pkgs.sudo}/bin/sudo` is not setuid in the Nix store. The immutable helper therefore fails before validating its exact grants even though the rendered sudoers policy is correct. NixOS intentionally provides privileged sudo through the root-managed `/run/wrappers/bin/sudo` trampoline.

## What Changes

- Invoke sudo through the canonical NixOS setuid wrapper while keeping systemctl, lsof, the owner unit, and the device path argument-exact.
- Add positive checks for the canonical wrapper path and negative checks rejecting a raw store sudo executable.
- Rebuild, activate, and validate the capability without isolating the service or accessing hardware.

## Impact

- **Behavior**: `ttwkv7-owner-control validate` can inspect its exact non-interactive grants on NixOS.
- **Security**: The user-controlled surface does not expand; only the root-managed sudo entrypoint changes.
- **Files**: `pkgs/ttwkv7-owner-control/default.nix`, `flake-outputs/_machine-checks.nix`, and the Tenstorrent runtime Cairn specification.
- **Operations**: Activation may continue to report the pre-existing unrelated mesh-LLM SOPS decryption failure; acceptance requires current-system/profile convergence, valid sudoers, polkit and owner health, and helper validation.
