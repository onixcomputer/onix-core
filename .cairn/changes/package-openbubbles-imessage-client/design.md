# Package OpenBubbles Desktop Client

## Context

BlueBubbles requires a companion Mac server that proxies Apple services. OpenBubbles replaces that with direct Apple service access from each client. onix-core has no OpenBubbles package, and nixpkgs has none either (verified by attribute evaluation). The upstream Linux release is a Flutter GTK bundle: a `bluebubbles` ELF plus `data/` and `lib/` siblings, including the Rust push core (`librust_lib_bluebubbles.so`) and the ObjectBox local store. `ldd` on the artifact reports only system libraries: GTK3, WebKitGTK 4.1, libsoup 3, libmpv, libnotify, libappindicator3, libdbusmenu-glib, fontconfig, and the C++ runtime.

## Decisions

### 1. Package the release tarball, not a source build

**Choice:** Wrap the pinned official Linux release tarball with `autoPatchelfHook` and a wrapper that adds the bundled `lib/` to `LD_LIBRARY_PATH`. Keep `data/`, `lib/`, and the executable as siblings so the Flutter engine resolves its bundle.

**Rationale:** A source build requires the Flutter toolchain plus the rustpush submodules, the forked `quinn`/`rustls`/`rtc` crates, and CloudKit protobuf generation. A pinned binary wrap is smaller, reproducible through the pinned hash, and easier to update. The bundle is self-contained apart from common system libraries.

### 2. Resolve system libraries with autoPatchelfHook

**Choice:** List the leaf runtime dependencies reported by `ldd` as `buildInputs`: `gtk3`, `webkitgtk_4_1`, `libsoup_3`, `libnotify`, `libappindicator-gtk3`, `libdbusmenu`, `mpv`, `fontconfig`, and `stdenv.cc.cc.lib` for `libstdc++`.

**Rationale:** These attributes all exist in nixpkgs (verified). `gtk3` and `webkitgtk_4_1` supply the transitive GTK/GLib leaves.

### 3. Expose as an x86_64-linux flake package

**Choice:** Register `openbubbles` in `flake-outputs/tools.nix` under the x86_64-linux package block, matching `sone`, `opendeck`, and `open-notebook`.

**Rationale:** The artifact is x86_64-linux only, and the repo already segments such binary packages in that block. The flake package gives a first-class build target for the gate.

### 4. Swap the social profile install

**Choice:** Replace `pkgs.bluebubbles` in the shared social profile with `pkgs.callPackage ../../../../pkgs/openbubbles { }`, and update the brittonr social imports accordingly.

**Rationale:** The social profile is only enabled on x86_64-linux machines (`britton-desktop`, `britton-fw`, `bonsai`, `aspen3`; the darwin `britton-air` carries no tags), so no platform guard is required. The `brittonr/dev/tools.nix` profile already uses this `callPackage`-from-profilesBasePath pattern.

## Risks / Trade-offs

- Upstream ships infrequent releases; the pinned bundle must be re-pinned on each new release.
- Apple can throttle or block an account; that is outside the package's control and does not affect packaging.
- The desktop client is GUI-only. An always-on iMessage node still needs the client running; `britton-desktop` is configured to never sleep.
