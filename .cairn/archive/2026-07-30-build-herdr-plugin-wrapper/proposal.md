## Why

The current Herdr profile installs plugins through a manual network command. This process leaves the installed plugin set outside the Nix generation.

A Herdr wrapper can provide the reviewed plugin set from immutable Nix store paths. Herdr must keep user sessions, configuration, state, and extra plugins mutable.

## What Changes

- Build the pinned Herdr plugins during the Nix build.
- Add a small Herdr patch that merges an immutable plugin registry with the user registry.
- Wrap the existing `llm-agents` Herdr package with the immutable registry and required runtime commands.
- Replace the manual plugin synchronization command and local Pueue link with the wrapped package.
- Keep Home Manager activation free of network access, Cargo builds, plugin registration, and server restarts.

## Impact

- **Files**: Herdr packaging, the workstation package list, the Home Manager profile, focused checks, Cairn specifications, and `README.md`.
- **Testing**: Focused Herdr unit tests, plugin package builds, wrapper checks, Home Manager checks, Cairn gates, and system evaluation.
