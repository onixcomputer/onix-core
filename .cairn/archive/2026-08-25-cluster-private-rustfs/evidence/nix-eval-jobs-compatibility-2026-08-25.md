# Aspen1 evaluator compatibility evidence

## Scope

This evidence covers the `nix-eval-jobs` package needed by Aspen1's Buildbot worker. It does not prove live deployment or RustFS cluster behavior.

## Negative baseline

The Nixpkgs `nix-eval-jobs 2.35.1` source failed against the wasm-enabled Onix Nix `2.36.0` components.

Observed compiler errors included:

- `Derivation` has no member named `inputDrvs`.
- `Derivation` has no member named `outputsAndOptPaths`.
- `parseFlakeRef` rejected the old settings argument.
- `InstallableFlake` rejected the old constructor call.

The failure blocked `unit-buildbot-worker.service` and the complete Aspen1 system build.

## Selected source

- Repository: `https://github.com/NixOS/nix-eval-jobs`
- Revision: `41235ab624bbb4e21c84ce30a76756921fe59f89`
- Source hash: `sha256-j72ybHHDR6b+abyBC+Dm1hSh6/ppllH3jO/dgahMixA=`
- Upstream purpose: port `nix-eval-jobs` to Nix 2.36 derivation and flake APIs.

The upstream revision targets a newer Nix master snapshot. The local patch uses the earlier Nix 2.36 `FullInputs.drvs` tree and pre-`AutoCall` `toValue` signature.

## Positive package result

The patched package compiled and installed successfully against the Onix Nix `2.36.0` component set.

Observed package output:

`/nix/store/5a5wd3x3aclfyn0d6wg1490p0fj03iyf-nix-eval-jobs-2.36.0-unstable-2026-08-24`

The subsequent complete Aspen1 system build also passed. Final system paths are recorded by the build task after the last source snapshot.

## Non-claims

- This evidence does not prove Buildbot runtime behavior on Aspen1.
- This evidence does not prove RustFS runtime behavior.
- The compatibility patch remains temporary until Nixpkgs provides a matching source.
