## Why

Reducing build pressure is not only about throttling local compilers. `britton-desktop` should avoid local builds when trusted substitutes are available, should not query duplicate caches, and should have an explicit workflow for remote-builder-only heavy builds. Current substituter configuration includes duplicate entries and local/remote cache ordering that should be made intentional.

## What Changes

- Normalize `britton-desktop` substituter ordering and remove duplicate entries.
- Document when the local Aspen cache should be queried before or after public caches.
- Add a verification path for remote-builder-only builds using `--max-jobs 0`.

## Capabilities

### New Capabilities
- `desktop-build-cache-routing`: Intentional cache/substituter routing for desktop build avoidance.

## Impact

- **Files**: Nix settings for `britton-desktop` or shared builder/cache modules.
- **APIs**: Operator build workflow documentation only.
- **Dependencies**: No new dependency required.
- **Testing**: Evaluate resolved substituters, verify no duplicates, and run a small remote-builder-only probe when builders are reachable.
