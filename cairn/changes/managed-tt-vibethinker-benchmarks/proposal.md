## Why

Repeating the VibeThinker Metalium comparison currently requires an operator to stop and later restore the root-owned production service by hand. Ad hoc benchmark commands have also written TT-Metal Inspector artifacts into the repository when launched from the worktree. The benchmark matrix should be reproducible and Nix-owned without converting the slower llama.cpp mesh path into the production serving configuration.

## What Changes

- Add a tested Rust benchmark core that runs the fixed device-0, device-1, and physical P150x2 `1x2` matrix and emits validated JSON summaries.
- Add a `britton-desktop` systemd oneshot and operator command that preserve the VibeThinker service's prior active state across successful and failed benchmark runs.
- Keep mutable TT-Metal caches, logs, Inspector output, and benchmark results in service-managed directories outside the source repository.
- Preserve the existing single-card production VibeThinker service and its accepted latency configuration.

## Impact

- **Files**: `pkgs/tt-vibethinker-bench/`, `flake-outputs/tools.nix`, `machines/britton-desktop/configuration.nix`, `flake-outputs/_machine-checks.nix`, Tenstorrent operator documentation, and Cairn lifecycle artifacts
- **Testing**: Rust positive and negative unit tests, package build, `britton-desktop` accelerator check, Nix formatting/pre-commit, and Cairn validation
