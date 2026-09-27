# Qwen3.8 continuous slots and Mesh-LLM rejoin on britton-desktop (2026-09-27)

## Continuous-slot scheduler deployed

- `6b7aa3aa` bumps `tenstorrent-nix-qwen` to tenstorrent.nix `8f5175d` and enables
  `hardware.tenstorrent.qwen38.continuousSlotScheduler`.
- System `/nix/store/8bjvcmd13kk05cbwf6al5ggy7zf01p24-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`
  was switched at 18:04:58 UTC. The unit runs qwen38
  `/nix/store/jxhspibs4ml8sbspj16bynhb1yp887vb-qwen38-0.1.0` with
  `--continuous-slot-policy …/share/qwen36/continuous-slot-policy.json`. That is the
  package and scheduler profile admitted by
  `pkgs/qwen36/evidence/2026-09-27/qwen38-continuous-slot-admission-receipt.json` in
  tenstorrent.nix.
- The only closure changes were qwen38, the policy files, and b3sum. Dry-activate
  restarted only `kiln-aspen-canary-lattice`, `polkit` and `qwen38-p150x2`.
- The switch reported the same failures as the two earlier switches that day:
  - the `build-storage-zfs-properties` activation snippet;
  - `celld`, `celld-site`, `collie-serve` and `kiln-aspen-ci-host`.
- Readiness took 157 s. `device-dram` reported 9,919,391,744 B free, the same as the
  screened roots.
- On the desktop:
  - Two overlapping requests on 127.0.0.1:8000 both reported decode path
    `continuous-slot`. The short one arrived 3 s into a 400-token request. It ran in
    slot 1 at generation 2, queued 0.47 s, and finished in 1.38 s. The long request
    held slot 0.
  - A request through the desktop's Mesh-LLM API on 9337 was also served by
    `continuous-slot`.

## Mesh partition found and repaired

The first request from aspen3 through its Mesh-LLM returned
`model 'Qwen3.8-27B' is not currently available`. Both nodes listed no peers.

The desktop's log showed the cause:

- aspen3's RTT rose to 5–12 s between 17:03 and 17:06 UTC.
- At 17:10:09 the desktop reported `Heartbeat: 9bc5bd2725 unreachable (1/2)`.
- At 17:11:19 it reported `Peer 9bc5bd2725 died — removing and broadcasting`.
- From then on it only ran mDNS LAN rediscovery, 33 times, and every attempt
  reported: `No joinable LAN meshes found … mDNS rediscovery only considers
  advertisements matching a supplied --join token`.

The invites passed with `--join-file` are read once at start, and mDNS cannot see the
tailnet hosts. The mesh stayed split for about an hour. The partition began before
this deployment.

Restarting `mesh-llm-mesh-llm-private-inference` at 18:11 UTC rejoined the invites:
`Connected to bootstrap peer; awaiting mesh admission`. Then a request from aspen3
through its Mesh-LLM returned `ready` from `continuous-slot`.

## Joiner rejoin watchdog

`modules/mesh-llm/mk-nixos-config.nix` extends the API watchdog for joiner nodes:

- After the startup grace, if the console reports an empty peer list for 5 checks in
  a row, the watchdog restarts the sidecar so it joins its invites again.
- It restarts at most once per 30 minutes.
- An unanswered console does not count.
- The seed node keeps only the API-listener check.

`mesh-llm-sidecars` now greps every joiner's watchdog for the rejoin path and rejects
it on the seed.

The change was deployed as
`/nix/store/mqz7r77pb7jnq4waw8z835mzp7mwnrm4-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`;
only the watchdog unit changed.

### Verification

- Deployed-script logic. The installed script was copied with a fake `systemctl` and
  a fake console. With an empty peer list it:
  1. reported `1/5` through `4/5`;
  2. restarted once on the fifth check;
  3. started counting again.

  A reported peer cleared the count. Five more empty checks within the backoff did
  not restart again (`the last rejoin restart was 1 s ago`).
- Live partition attempts did not reproduce the heartbeat death:
  - Dropping the desktop's UDP to aspen3's tailnet address for 5 minutes: the
    connection survived, apparently through another path.
  - Dropping every non-loopback packet the `mesh-llm` user sent for 3 minutes: no
    heartbeat warning was logged, and the peer was still listed when the block
    lifted.

  The restart path itself is proven by the 18:11 manual restart above.

## Not done

- aspen3 (also a joiner) was not redeployed. `modules/mesh-llm/mk-nixos-config.nix` is
  mirrored into the `~/git/onix-core` working tree, so it takes the watchdog at its
  next deploy. Until then, the desktop's watchdog heals a desktop–aspen3 split from
  the desktop side.
- The underlying Mesh-LLM behaviour is unchanged: a joiner that loses a peer still
  retries only mDNS.
