# Herdr Fleet Installation Delta

## Purpose

Extend the existing wrapped Herdr installation to Aspen1, Aspen2, and Bonsai without changing the shared runtime or unrelated machine assignments.

## ADDED Requirements

### Requirement: Aspen1 installation [r[onix.herdr.fleet.aspen1]]

Aspen1 MUST install the existing wrapped Herdr package from this flake's package outputs while preserving its existing system packages.

### Requirement: Aspen2 installation [r[onix.herdr.fleet.aspen2]]

Aspen2 MUST install the existing wrapped Herdr package from this flake's package outputs while preserving its existing system packages.

### Requirement: Bonsai installation [r[onix.herdr.fleet.bonsai]]

Bonsai MUST install the existing wrapped Herdr package from this flake's package outputs while preserving its existing system packages.

### Requirement: Managed user profile [r[onix.herdr.fleet.profile]]

The explicit fleet Home Manager instance MUST assign the existing `brittonr/herdr` profile to Aspen1, Aspen2, Aspen3, and Bonsai. The desktop's existing Herdr assignment MUST remain intact. The profile MUST retain the generated TOML and Neovim navigation adapter without introducing plugin installation or server restarts during activation.

### Requirement: Runnable configuration [r[onix.herdr.fleet.verification]]

Each requested machine's selected Herdr package and generated Home Manager files MUST evaluate, and the wrapped Herdr MUST accept the generated configuration. Verification MUST state the remote activation boundary.
