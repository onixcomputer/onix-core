## Why

The 2026-10-21 flake update (`8537fe09`) needed temporary workarounds to
build the fleet. Each one pins, skips, or permits something that should
follow the repository's nixpkgs again once the upstream cause is fixed.
Without one tracked list, they outlive their causes.

## What Changes

Track each workaround with the condition that retires it. No code changes
until a condition holds.

- **herdr 0.9.3**: the `llm-agents-herdr` input and its Zig 0.16 override in
  `inventory/tags/common/shared-nix.nix`. Retire when onixpkgs'
  `static-plugin-registry.patch` applies to the herdr in `llm-agents`.
- **Octet on older nixpkgs**: the `nixpkgs-octet` input that `tigerstyle`
  follows. Retire when `cargo-llvm-cov`'s tests pass on the repository
  nixpkgs.
- **ki-editor without typeshare doctests**: `withoutTypeshareTests` in
  `flake-outputs/tools.nix`. Retire when nixpkgs' typeshare doctests pass.
- **llamacpp-rocm-rpc without nixpkgs patches and tests**: the override in
  `shared-nix.nix`. Retire when onixpkgs' llama.cpp pin matches the nixpkgs
  recipe or carries its own.
- **hermes-agent dependency relaxation**: `pythonRelaxDeps` for
  `prompt_toolkit` and `markdown` in `modules/llm-agents` and
  `modules/hermes-gateway`. Retire when hermes-agent's pins accept the
  nixpkgs releases.
- **buildbot-effects wrapper arguments**: `modules/buildbot/effects-package.nix`.
  Retire when buildbot-nix passes `--prefix` words separately.
- **Dev-shell wrapper arguments**: `splitMakeWrapperArgs` for `clan-cli` and
  `pexpect-cli` in `flake-outputs/dev-env.nix`. Retire when clan-core and
  mics-skills pass each `makeWrapperArgs` word separately.
- **gcadapter module certificate**: `withModuleCertificates` in
  `inventory/tags/udev-rules.nix`. Retire when `gcadapter-oc-kmod` installs
  its own `.ko.cer`.
- **cutter and iaito**: removed from `inventory/tags/dev.nix`. Restore when
  nixpkgs builds them with Qt 6.12 (cutter with its Python bindings off).
- **minio-client**: the exact-version permit in the five RustFS-provisioning
  modules. Retire when nixpkgs drops the insecure marking or the modules stop
  using `mc`.

## Impact

- **Files**: none until a workaround is retired.
- **Testing**: each retirement builds the affected closures without the
  workaround and confirms unchanged behaviour on the machines that use it.

## Affected Specs

- `update-workarounds`: new capability tracking the retirement duty.
