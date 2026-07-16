# tenstorrent-native-runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 NixOS sudo trampoline
r[onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper] The managed ttWKV7 owner-control helper MUST invoke sudo through the root-managed NixOS setuid wrapper at `/run/wrappers/bin/sudo`, MUST NOT invoke a raw Nix store sudo executable, and MUST preserve the argument-exact privileged target commands defined by the owner-control policy.

#### Scenario: Exact grants validate on the activated host
- GIVEN the reviewed sudoers policy is activated
- WHEN the operator runs `ttwkv7-owner-control validate`
- THEN validation succeeds through `/run/wrappers/bin/sudo`
- AND no service state changes
- AND no Tenstorrent device is accessed

#### Scenario: Raw store sudo regresses
- GIVEN the generated immutable owner-control helper
- WHEN device-free package validation inspects its command composition
- THEN validation fails if the helper references `${pkgs.sudo}/bin/sudo` or another raw store sudo executable
- AND validation fails if the canonical NixOS sudo wrapper path is absent

#### Scenario: Unauthorized lifecycle command is attempted
- GIVEN the activated owner-control sudo policy
- WHEN the operator requests restart or another unreviewed systemctl argument vector non-interactively
- THEN sudo rejects the command
- AND the owner service remains active and healthy
