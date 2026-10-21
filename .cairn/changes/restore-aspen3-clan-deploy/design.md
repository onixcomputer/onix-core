## Build host identity

Clan parses a build host without a user as `root@`. On britton-desktop, root has no GitHub key, and a forwarded agent cannot reach the YubiKey. Evaluation therefore fails while fetching `bounded-exec`. brittonr's key reaches GitHub and aspen3's root, so it also covers the closure copy that runs on the build host.

## Evaluation inputs

The configuration imports files from other in-flight changes that Git did not track, so they are marked intent-to-add. The pinned nixpkgs ships Grafana 13.1.6. Its `public/emails` bytes match all 18 vendored hashes, so only the manifest version changes.

## Underclass on aspen3

The repository enabled a local Underclass service on aspen3. The live host already used the desktop pool through a hand-installed SSH tunnel. The shared-pool mode from the isolated Underclass worktree keeps that arrangement under Home Manager. `add-underclass-omp` records the mode.

## Runtime handover

`/etc/systemd/system.control` outranks `/etc/systemd/system`, so the attached laya and mesh-llm units would have kept overriding the generation. Home Manager would have renamed the hand-installed tunnel unit and extension to `.hm-bak`. These paths were moved to backups before the switch. The running processes continued until the switch restarted mesh-llm and the tunnel.

## Activation

Pre-existing celld failures make `switch-to-configuration` exit 4 while the USB4 NVMe is absent. Clan retries once and accepts the switch when `/run/current-system` equals the built toplevel.

## Risks / Trade-offs

- aspen3 builds depend on brittonr's SSH key on britton-desktop.
- aspen3 keeps `min-free = 100 GiB` with about that much space free. Auto-GC can remove a copied closure before activation if a deployment stalls.
