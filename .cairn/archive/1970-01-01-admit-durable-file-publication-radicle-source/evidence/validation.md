# Validation Evidence

Date: 2026-07-27

## Focused checks

The focused Radicle node, replica, and durable publication admission checks passed.
Both host NixOS closures built successfully before deployment.
Cairn validation and the proposal, design, and tasks gates passed.

The focused traceability profile covered 6 of 6 accepted requirements.
It reported no missing or dangling references.
Its receipt hash was `126bc1fe4b9738f68d52b435658115eacffcac97a837a20abdf0c435d813377c`.

Accepted-spec synchronization completed with receipt hash `0459295d46984717362872ce98095586bd19bfbf8d1a43d1b1f09cbd70aed4e8`.

## Broad repository rail

`nix flake check -L --option allow-import-from-derivation true` ran after the focused checks.
It stopped at the unrelated `checks.x86_64-linux.no-stale-color-refs` check.
That check found an existing `config.colors` reference in `inventory/home-profiles/brittonr/noctalia/wezterm.nix`.
This change does not edit that file or the theme migration.

## Evidence boundary

These checks prove bounded policy, build, deployment, endpoint, and traceability observations for this change.
They do not prove future availability, indefinite synchronization, release authority, delegate authority, backup completeness, or whole-repository correctness.
