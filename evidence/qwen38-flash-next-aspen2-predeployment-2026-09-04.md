# Aspen2 Qwen3.8 Flash Next predeployment evidence

Date: 2026-09-04

Host: `aspen2`

Later status: [NixOS installation on 2026-09-06](aspen2-nixos-install-2026-09-06.md) passed boot and SSH checks.
Qwen GPU allocation and Tailscale login still block live service acceptance.

## Prepared configuration

r[verify onix.aspen2.qwen_flash.serving.inventory]

- The inventory defines `llamacpp-server-qwen38-flash-next-aspen2`.
- The service reuses the complete Aspen1 artifact and runtime settings.
- The direct server binds to `127.0.0.1:13305`.
- The Aspen2 mesh joiner routes to `llamacpp-server-qwen38-flash-next-aspen2.service`.
- The model revision remains `d2e41a316ee631cf17f83c8827800c836d30cbe6`.
- The three IQ4_XS shard hashes and F16 projector hash remain unchanged.

r[verify onix.aspen2.qwen_flash.exclusivity.no_competitors]

- The evaluated Aspen2 configuration provides the Qwen service.
- The evaluated Aspen2 configuration does not provide `lemonade.service`.

## Credential preparation

The Aspen1 Hugging Face credential was copied through Clan without printing it.
Aspen2 has encrypted `huggingface-token` and `env-file` vars.
`clan vars check` reported that all selected vars are present and valid.

## Build validation

- Nickel formatting passed.
- Nickel export passed.
- Cairn validation returned `valid: true`.
- Deadnix passed.
- Treefmt passed.
- The focused `llamacpp-server-settings` check built successfully.
- The focused `mesh-llm-sidecars` check built successfully.
- The complete Aspen2 NixOS system built successfully.

Build outputs:

- `/nix/store/khwc5p3qz2isjgb1ls76yrh2cpmdjfvn-llamacpp-server-settings`
- `/nix/store/qbss8r28kxzjryla5a7awwzyz6hnk0ka-mesh-llm-sidecars`
- `/nix/store/dhxg9psrm0djki0pc04xdqn3xnzz5ijs-nixos-system-aspen2-26.11.20260819.afe3d8a`

The remote build used source archives for two inaccessible private inputs.
Each archive used the exact locked commit and NAR content.
No lock file changed.

Repository-wide Statix still reports existing repeated-key warnings in unrelated modules.

## Activation blocker

Aspen2 is powered off or otherwise disconnected.

- `aspen2.local` does not resolve.
- Tailnet address `100.125.64.121` does not answer SSH or ICMP.
- Tailscale reports Aspen2 offline and last seen 78 days ago.
- Aspen1 cannot reach Aspen2 at `10.10.10.2`.
- The repository contains no approved remote wake mechanism for Aspen2.

## Remaining acceptance work

After Aspen2 is online, the deployment still requires these observed effects:

1. Stage the four verified model files while Lemonade remains active.
2. Upload the encrypted Clan vars.
3. Activate the built Aspen2 generation.
4. Verify the clean hash-guard restart.
5. Run health, text, vision, mesh, isolation, and malformed-token probes.
6. Record memory use, speed, service state, and restart count.

## Non-claims

- This evidence does not claim that Aspen2 runs Qwen.
- This evidence does not satisfy the Aspen2 live-validation requirement.
- This evidence does not prove current Aspen2 disk or memory availability.
- Aspen1 remains the only live Aspen Qwen endpoint at this time.
