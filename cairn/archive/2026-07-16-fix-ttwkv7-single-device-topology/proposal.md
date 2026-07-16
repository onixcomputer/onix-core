# Change: Isolate ttWKV7 from the host mesh descriptor

## Why

The first bounded Blackhole P150 smoke test reached TT-Metal device discovery but aborted before WKV execution because the host-wide P150x2 `TT_MESH_GRAPH_DESC_PATH` was inherited while ttWKV7 opens a one-device unit mesh. The package must enforce its single-device topology boundary instead of depending on the caller's session environment.

## What Changes

- Clear `TT_MESH_GRAPH_DESC_PATH` in the packaged `wkv7` wrapper before TT-Metal starts.
- Add install-time positive and negative wrapper assertions so the isolation cannot regress silently.
- Rebuild and deploy the corrected package, then run one bounded hardware test with the owning service isolated and restored.

## Impact

- **Affected spec:** `tenstorrent-native-runtime`
- **Affected code:** `pkgs/ttwkv7/default.nix`
- **Operational risk:** A hardware rerun remains experimental because upstream targets Wormhole; it must remain single-shot with captured evidence and guaranteed service restoration.
