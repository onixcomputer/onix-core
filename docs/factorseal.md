# Factorseal evaluation

Factorseal is an unaudited hardware-backed vault prototype, not an approved store for production secrets.
Onix pins `cachix/factorseal` at `848c0ceb9f500b7be5d6a15e63d8113ddcde619a` under Apache-2.0.
The upstream packages support `x86_64-linux` and `aarch64-linux`.
This integration does not enable a machine, start a service, initialize a vault, or migrate secrets.
Clan vars, SOPS, and existing keyrings remain unchanged.

## Package use

Build the CLI:

```console
nix build .#factorseal
```

Inspect the CLI without initializing a vault:

```console
nix run .#factorseal -- --help
```

The separate `factorseal-desktop` package provides the graphical vault host.
Package installation alone does not grant TPM access.
Linux requires TPM 2.0 and password-backed unlock.
Factorseal rejects a software-only fallback.

## Optional NixOS integration

The exported `nixosModules.factorseal` wraps the pinned upstream module.
The wrapper requires explicit acceptance of the prototype before service activation.
Nix is the native module format. No separate Nickel configuration or secret export step is necessary.

For a disposable evaluation host, import the module and select the user:

```nix
{ inputs, ... }:
{
  imports = [ inputs.onix-core.nixosModules.factorseal ];
  services.factorseal = {
    enable = true;
    acceptUnauditedPrototype = true;
    users = [ "evaluation-user" ];
    mode = "agent";
  };
}
```

The user must already exist. The upstream module enables TPM access and polkit.
It installs a global systemd user service. The `users` list grants TPM group membership, not exclusive permission to start that service.

The upstream defaults define the idle and absolute lease deadlines.
The module rejects an idle deadline greater than the absolute deadline.
It also rejects an enabled GNOME Keyring service.
Other Secret Service providers, including oo7 and Home Manager keyring services, require a separate conflict review.
This integration does not disable those providers automatically.

Desktop mode owns `org.freedesktop.secrets` and supports D-Bus activation.
It replaces agent mode rather than connecting to the agent.
Do not enable both hosts or another Secret Service provider in the same user session.

## Secret and upgrade boundaries

Use only disposable secrets during evaluation.
Keep passwords out of Nix expressions, command arguments, environment files, and the Nix store.
Initialize and unlock interactively through the upstream CLI or Desktop.

Executable grants bind to the binary digest.
After a package upgrade, stop the service and use `factorseal grant-cli` to authorize the new executable.
Project approvals also require renewal.
Never approve those grants automatically during a system rebuild.

A copy of the vault directory does not replace a portable encrypted export.
Hardware loss can make that directory unusable.
Factorseal does not detect rollback of the complete vault directory.
The upstream release still requires independent security review and physical-device acceptance.
The local policy check does not prove TPM operation, crash recovery, or production readiness.

## Checks

Run the configuration checks:

```console
nix build .#checks.x86_64-linux.factorseal-policy
```

The checks cover disabled defaults, explicit acceptance, TPM group membership, and agent registration.
Negative cases cover missing acceptance, an invalid lease, and a GNOME Keyring conflict.
The generic package checks also include both exported Factorseal packages.
Physical TPM acceptance remains a separate, interactive upstream procedure.

## Current build blocker

The local configuration check passed on `x86_64-linux`.
The CLI build failed while fetching the pinned Automerge dependency at `76746a304deecf001b4a78d6625dd0eb1ab48ddd`.
Nix reported these source hashes:

```text
specified: sha256-UnoH9y7pgq8TThwm7u5kQzucsWnFUcHIZgNGH0hABM4=
got:       sha256-5Bz/X61A/HVe4t6xLLQ2a5i5GTKZBFpVXs7D/5xT0gg=
```

The integration retains the upstream expected hash.
Package acceptance remains blocked until source verification resolves this mismatch.
No CLI runtime, Desktop build, or hardware acceptance claim follows from the configuration check.
