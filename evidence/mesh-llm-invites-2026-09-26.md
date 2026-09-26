# One Mesh-LLM network across britton-desktop, aspen2 and aspen3

Date: 2026-09-26

## Before

- Every joiner's single invite pointed at the seed, aspen1 (`100.100.103.95:47916`). aspen1 has been offline on Tailscale for two days.
- britton-desktop and aspen2 were connected, through the LAN beacon on their shared LAN.
- aspen3 was isolated. It is now reachable only over Tailscale (`aspen3-1`, 100.108.13.4) and restarted at 10:27. Its status reported `mesh_id: null` and no peers.

## Change

On `underclass-mesh-desktop`:

- `5ef74f6c` adds the per-node invites and the shared invites generator.
- `a760549e`, `fbdcdd24`, `29398fee` and `603e84a8` enter the four invites. Each was read from that node's `/api/status`; aspen1's came from a joiner's current credential. Every invite was checked to decode to the node's own Tailscale address and a 64-hex endpoint ID before it was stored.

aspen2 and aspen3 are deployed from the uncommitted tree in `~/git/onix-core` (`bookshelf-fetch` at `c5001ff2`). The same change is carried there as working-tree edits:

- the new files are marked intent-to-add;
- the retired `join-token` vars are deleted from the working tree;
- `flake-outputs/_mesh-llm-checks.nix` is merged with that tree's own edits.

## Verification

- `checks.x86_64-linux.mesh-llm-sidecars` passed on both trees, and `britton-desktop-accelerator-inventory` passed on this lineage.
- Evaluated invite order for the joiners, with no invites for the seed:

  | Node | Invites, in order |
  |---|---|
  | britton-desktop | aspen2, aspen3, aspen1 |
  | aspen3 | aspen2, britton-desktop, aspen1 |
  | aspen2 | aspen3, britton-desktop, aspen1 |

- **britton-desktop**, generation 864:
  - `/nix/store/f45i22rc48m35g6lpaz326m4dxqb5f3x-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`.
  - Against generation 863 the only changes are the mesh-llm unit (three `--join-file` invites, three `LoadCredential` entries) and the vars. The retired join-token is removed and the four shared invites are added.
- **aspen3**:
  - `/nix/store/q77l9yfgkakckkpdx3syjq8w4782alv9-nixos-system-aspen3-26.11.20260924.34ca302`, built from the uncommitted tree plus this change.
  - Without the change, that tree already differed from aspen3's running system only in the mesh-llm package, its config and the units that depend on them. The difference is the openai-endpoint plugin-name patch from the in-progress Underclass mesh work.
  - It was copied with `nix copy`, dry-activated, and activated with `nix-env --set` and `switch-to-configuration switch` under `systemd-run`.
- Both switches exited with status 4, from units that were already failing:
  - britton-desktop: `kiln-aspen-ci-host`.
  - aspen3, with failures earlier the same day: `amd-gpu-exporter` (3,641), `celld` (6,317), `tailscale-host-sync` (311), `celld-site-storage-provision` (2).

## Runtime result

| Node | Peers (RTT) |
|---|---|
| britton-desktop | aspen2 (1 ms), aspen3 (79 ms) |
| aspen2 | britton-desktop (1 ms), aspen3 (54 ms) |
| aspen3 | aspen2 (51 ms), britton-desktop (83 ms) |

- **aspen3 → desktop model:** aspen3's `/v1/models` lists `Qwen3.8-27B`. A chat completion sent to aspen3's mesh API was answered by the desktop's P150x2 service (TT-Metal 0.77, 24.0 decode tokens/s).
- **Desktop → aspen3 models:** britton-desktop's `/v1/models` lists aspen3's models: Whisper, Ornith 35B and 9B, Qwen3.6-35B-A3B and VibeThinker-3B.
  - Requests for them reach aspen3, but aspen3's Lemonade cannot start `llama-server`: `LLVM ERROR: IO failure on output stream: No space left on device`.
  - The same request fails the same way when sent locally on aspen3.
  - The cause is aspen3's `/tmp`, a 61 GB tmpfs that is full, not the mesh.
- **aspen1** is still offline. Every joiner holds its invite last and re-dials it each minute.
- **aspen2** keeps its old single invite until its next deployment. It is connected because aspen3 and britton-desktop dial it.
