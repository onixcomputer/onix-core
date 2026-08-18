## Why

`britton-desktop` has a managed Herdr profile, but it does not provide the five requested workflow plugins. An exact `nix search nixpkgs` query returned no matching package for any requested project.

Four projects can use Herdr's native GitHub plugin installer. `ghzinga` also needs its Rust command on `PATH`, so Nix must own that runtime package.

## What Changes

- Package `ghzinga` from its pinned upstream release and install it through the Herdr Home Manager profile.
- Record exact commit references for all five trusted Herdr plugin sources in typed Nickel data.
- Add a manual `sync-herdr-plugins` command that installs those exact references through Herdr.
- Keep Fish `CDPATH` local so Bash plugin scripts do not receive command-substitution noise.
- Add typed File Viewer, reviewr, and Vim navigation actions without mutating plugin state during activation.
- Load the upstream Neovim navigation adapter from a fixed-output source.
- Add focused positive and negative checks for package, source, action, editor, and ownership behavior.

## Impact

- **Files**: `pkgs/ghzinga`, package outputs, the shared keymap, the Herdr profile, focused checks, and `README.md` references.
- **Runtime state**: `sync-herdr-plugins` changes Herdr-owned plugin state only when the operator runs it.
- **Testing**: Build `ghzinga`, evaluate Nickel, build the focused Herdr check, evaluate `britton-desktop`, and run Cairn gates.
