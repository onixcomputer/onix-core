## Context

The managed profile renders `~/.config/herdr/config.toml` from typed Nickel data. Existing policy keeps plugin installation out of Home Manager activation because Herdr owns a mutable global plugin registry.

The requested projects use three runtime shapes:

- File Viewer, reviewr, and Mirror include Rust binaries and Herdr manifests with release download steps.
- Vim Herdr Navigation includes shell actions and a separate Neovim adapter.
- `ghzinga` includes a Rust command and a thin Herdr plugin under `plugins/herdr`.

## Completion Contract

The change is complete when Nix builds and installs `ghzinga`, the profile records five exact plugin commits, and the manual sync command installs all five sources. The generated Herdr config must contain the selected actions. Neovim must load the navigation adapter.

The following results are not completion:

- Documentation-only references without an executable sync path.
- Unpinned GitHub plugin installs.
- Home Manager activation that mutates Herdr plugin state.
- A registered `ghzinga` plugin without `gzg` on `PATH`.
- Vim navigation actions without the Neovim edge-navigation adapter.

## Decisions

### Decision: Use native Herdr checkouts for plugin state

**Choice:** Generate a manual `sync-herdr-plugins` command from typed source and commit records. Do not run this command during evaluation or activation.

**Rationale:** Herdr validates manifests, runs each upstream build step, owns replacement checkouts, and preserves plugin config and state. A manual command keeps network and executable side effects explicit.

### Decision: Pin plugin commits, not moving tags

**Choice:** Pass exact release commit hashes through `herdr plugin install --ref`.

**Rationale:** Exact commits prevent tag movement from changing future sync results. The checked-out manifests still carry their release versions, so upstream release download steps select matching assets.

### Decision: Package only the missing external runtime

**Choice:** Build `ghzinga` as an Onix package and add it to the Herdr Home Manager profile.

**Rationale:** The other Rust binaries live inside Herdr-managed plugin roots and their manifests invoke relative paths. `ghzinga` is different because its plugin invokes `gzg` from `PATH`.

### Decision: Keep action data typed and adapters declarative

**Choice:** Derive File Viewer, reviewr, and Vim navigation action keys from the shared Nickel keymap. Load the pinned Vim navigation Lua adapter through Home Manager.

**Rationale:** Typed keys catch empty values before TOML generation. The Neovim adapter completes edge handoff without a mutable editor plugin install.

### Decision: Do not export Fish CDPATH

**Choice:** Keep Fish `CDPATH` global but not exported. The sync command also clears an inherited `CDPATH` before it runs plugin builds.

**Rationale:** Bash prints a matched `CDPATH` destination during `cd`. Some upstream plugins capture `cd` and `pwd` together, which corrupts their computed root path.

## Approach Registry

| Family | Mechanism | State | Evidence or blocker |
| --- | --- | --- | --- |
| Nixpkgs reuse | Install matching nixpkgs packages | Falsified | Exact search returned `{}` for all five names. |
| Nix-store plugin roots | Link immutable package roots into Herdr | Rejected | Registry paths can retain old store paths after an upgrade, and builds duplicate Herdr ownership. |
| Activation install | Run `herdr plugin install` from Home Manager | Rejected | This adds network, executable, and mutable-state effects to activation. |
| Native pinned sync | Run an explicit generated command against exact commits | Selected | This matches Herdr's documented global registry and install contract. |

The local VibeThinker audit timed out, so it supplied no authority. Herdr plugin documentation and deterministic repository checks remain the evidence sources.

## Risks / Trade-offs

- A plugin install runs third-party code as the user. Exact commits bound the source but do not sandbox it.
- Sync needs GitHub access and the tools required by upstream install scripts.
- Direct `Ctrl+h/j/k/l` actions shadow normal shell bindings while Herdr has focus. This is the requested plugin's documented behavior.
- A currently running Herdr server can retain an old exported `CDPATH` until its next restart.
- Mirror remains dormant until the operator provides `hosts.toml`.
