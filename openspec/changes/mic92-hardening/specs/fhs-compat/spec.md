## ADDED Requirements

### Requirement: nix-ld enabled on desktop and dev machines
Machines with the `desktop` or `dev` tag SHALL have `programs.nix-ld.enable = true` so dynamically linked binaries can locate a standard interpreter.

#### Scenario: unpatched binary runs on desktop machine
- **WHEN** a user downloads a prebuilt Linux binary (AppImage, vendored CLI tool)
- **THEN** the binary executes without "No such file or directory" from a missing interpreter

### Requirement: nix-ld library set covers common dependencies
The `programs.nix-ld.libraries` list SHALL include libraries for: C runtime, compression, crypto/TLS, D-Bus, fontconfig/freetype, USB, and UUID. On machines with `hardware.graphics.enable`, it SHALL additionally include: Mesa, Vulkan, PipeWire, ALSA, PulseAudio, GTK3, X11 libs, and libxkbcommon.

#### Scenario: Electron app runs without missing .so
- **WHEN** a user runs an Electron-based AppImage on a desktop machine
- **THEN** all common shared libraries (libGL, libX11, libgtk-3, libasound, etc.) are found via nix-ld

#### Scenario: headless dev machine skips graphics libraries
- **WHEN** a machine has the `dev` tag but not `desktop` (no `hardware.graphics.enable`)
- **THEN** only the base library set is provided (no Mesa, Vulkan, GTK, X11)

### Requirement: envfs enabled on desktop and dev machines
Machines with the `desktop` or `dev` tag SHALL have `services.envfs.enable = true` so `/usr/bin/env` and other FHS paths work for scripts with shebangs like `#!/usr/bin/env python3`.

#### Scenario: script with env shebang runs
- **WHEN** a user executes a script starting with `#!/usr/bin/env bash`
- **THEN** envfs resolves the interpreter from the Nix profile and the script runs

### Requirement: fhs-compat config lives in a dedicated tag file
The nix-ld and envfs configuration SHALL be placed in a new `inventory/tags/fhs-compat.nix` file (or added to an existing appropriate tag). Machines opt in by having the relevant tag.

#### Scenario: server without fhs tag is unaffected
- **WHEN** a server machine does not have the `desktop` or `dev` tag
- **THEN** nix-ld and envfs are not enabled on that machine
