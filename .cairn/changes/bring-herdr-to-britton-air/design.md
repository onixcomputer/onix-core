## Baseline and Scope

`britton-air` runs macOS 26.3.1 with Nix 2.34.9, no `builtins.wasm`, an empty
`~/.ssh/config`, no Home Manager profile, and no Herdr binary. Its nix-darwin
configuration enables the `nix.linux-builder` VM and the shared users, dev,
and Nix modules. `aspen3` runs Herdr 0.9.3 from `pkgs.herdr`, the `herdr`
Home Manager profile, `herdr-app` from the pinned llm-agents input, and the
herdr-iroh relay with the `britton-grok` peer and saved-machine gateway.

## Decisions

Render the Darwin Home Manager configuration through the same clan service as
NixOS. `perInstance` now returns both a `nixosModule` and a `darwinModule`;
each imports the matching upstream Home Manager module and shares the profile
list, `useGlobalPkgs`, `useUserPackages`, multiverse pins, and state-version
override. `britton-air` gets its own instance with `homeStateVersion = "26.05"`
because nix-darwin's `system.stateVersion` is not a Home Manager version.

Make Collie optional per platform in onixpkgs rather than in onix-core, because
package definitions belong in onixpkgs. The wrapper keeps its eight-plugin
bundle on Linux; on Darwin it keeps the other seven and drops the
`herdr.collie` source, id, and artifacts together. The Nickel config and key
bindings do not reference Collie actions, so both platforms render the same
`config.toml`.

Run herdr-iroh on Darwin as a per-user Home Manager `launchd.agents.herdr-iroh`
agent with `RunAtLoad`, `KeepAlive`, `HOME = /Users/brittonr`, the system
profile on PATH, and a generated server TOML with the same peer and gateway
settings as the NixOS module. The `herdr` profile imports the Darwin relay only
when `osClass == "darwin"` (using `pkgs` in an import would recurse). The
system-level tag keeps only the herdr-iroh CLI: a system LaunchDaemon with
`UserName = brittonr` could not `posix_spawn` the store binary (EACCES), while
the user agent runs from the same store path. The NixOS path continues to use
the upstream systemd module and its `XDG_RUNTIME_DIR` fix. A Home Manager
activation entry creates `/Users/brittonr/.local/state/herdr-iroh`; nix-darwin
only composes the named activation scripts, so a custom
`system.activationScripts.<name>` would be ignored.

Install the wrapped core in `environment.systemPackages` and `herdr-app` in
`home-manager.users.brittonr.home.packages`, matching aspen3. Do not move
`herdr-app` into the shared fleet profile: the Linux servers are headless.
The Home Manager profile also owns `~/.ssh/config` with the three aspen3
aliases (`britton-desktop`, `cproof-brittonr`, `instantfill-vm`) so the relay's
saved-machine gateway can expand them.

Seed the saved-machine list with the same three targets aspen3 has.
`britton-desktop` is added with `herdr machine add` and verifies as reachable.
`cproof-brittonr` and `instantfill-vm` are seeded into the same per-user
`endpoints.json` because they are currently unreachable from britton-air: the
Mac is asleep or off-network, and the VM is only on the tailnet while
britton-air has no Tailscale. `herdr machine list` therefore matches aspen3,
and `herdr machine status` reports their reachability honestly. Do not copy
the endpoint file into the repository.

## Build and Deploy

`britton-air`'s Nix cannot evaluate the Nickel inventory. Evaluate the
darwin toplevel on a wasm-capable host, then copy the resulting
`aarch64-darwin` derivation closure to britton-air and build it there with
remote builders disabled. The derivation is host-independent. For this
rollout the evaluation ran on aspen3 because the desktop's Nix daemon was
saturated by unrelated builds; a prebuilt Nickel evaluator stood in for the
flake's eval-time `wasm-plugins` output. That path does not enter the system
closure. After the build, set `/nix/var/nix/profiles/system` and run
`<system>/activate` as root.

## Verification

Require the evaluation to succeed with the patched onixpkgs input; the
britton-air core to report Herdr 0.9.3 with seven plugins (`herdr.collie`
absent); `herdr-app` to exist in the user profile; the Home Manager config
symlink to point at the rendered TOML with the same content hash as aspen3;
and `launchctl print gui/501/org.nix-community.home.herdr-iroh` plus the relay
log to show the agent running with the same endpoint policy. Then require
`herdr machine list` on britton-air to show the three aspen3 targets and
`herdr machine status` to report their reachability.

## Completion State

Deployed 2026-11-11:

- onixpkgs `de18d43acc410a38a2d5eee1e1c5dd8648b4db4e` is the pinned input.
- britton-air system `/nix/store/jjygp79jpxr4dm7wlb9rr807islrippd-darwin-system-26.11.bb0b90d`
  (generation `system-13-link`).
- Herdr 0.9.3, seven plugins, Herdr.app 0.1.14, rendered `config.toml` hash
  `3896e0418a91c1556717898b13e24ee20720b10b9de6eb3291130b1ad189e251` (identical
  to aspen3).
- The relay agent runs with endpoint `892127597af970511155b881294d7e3aed9a9cd9813225f6b0d48cbd5db4de10`,
  gateway enabled and one allowed peer.
- Saved machines list matches aspen3. `britton-desktop` is reachable;
  `cproof-brittonr` and `instantfill-vm` are listed but currently unreachable
  from britton-air (host off-network and tailnet-only, respectively).
