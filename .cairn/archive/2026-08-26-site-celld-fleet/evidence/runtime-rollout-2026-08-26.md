# Site Celld Fleet Runtime Rollout Evidence

Date: 2026-08-26

## Scope

This evidence covers one private two-node Site Celld fleet on `aspen3` and `britton-desktop`. The fleet uses the existing RustFS cluster, bucket `onix-site-celld`, and serves one asset-only Aspen documentation deployment. It does not cover the pre-existing `celld-lab` fleet beyond confirming that fleet still runs.

## Fleet composition

Each host runs two new units:

- `celld-site.service`: Celld `0.3.0` node, user `celld-site`, state `/var/lib/celld-site`, bucket `s3://onix-site-celld`.
- `celld-site-ingress.service`: hardened nginx adapter, `DynamicUser`, runtime directory only.

Listeners observed with `ss -ltn` on both hosts:

- `100.108.13.4:32110` / `100.110.43.11:32110`: nginx public ingress, admitted only on `tailscale0`.
- `100.108.13.4:32111`: Celld internal peer and operator listener.
- `127.0.0.1:32112`: Celld Worker backend, loopback only on both hosts.

A probe from britton-desktop to `http://100.108.13.4:32112/__celld/health` was refused. The backend is not reachable from a Tailnet peer. All Site ports sit below the default Linux ephemeral range (`32768+`); an earlier `39210` choice collided with an ephemeral Prometheus source port and was rejected.

## Storage provisioning

The aspen3 provisioner created bucket `onix-site-celld`, user `celld-site`, and policy `celld-site-celld` scoped to that bucket only. After credential rotation the provisioner ran again idempotently and completed successfully. The RustFS endpoints on both hosts reported healthy during rollout.

Credential files observed on aspen3:

- `/run/secrets/vars/shared/celld-site-celld/aws-env`: mode `0400`, owner `celld-site:celld-site`.
- `/run/secrets/vars/shared/celld-site-celld/publisher-aws-env`: mode `0400`, owner `brittonr:celld-site`, standard `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_EC2_METADATA_DISABLED` environment variables.

The publisher credential could list the Site bucket through RustFS and could not use EC2 metadata fallback.

## Deployment upload

The Site CLI staged 36 assets (240078 bytes) from `public/` with BLAKE3 output manifest identity `089903a73427566b0f3f171f3c4e74355ebc54af1245cd1fb08c07426ae31935`.

A dry run passed, then an explicit write uploaded deployment version `d2da6ae78748a86a` with `html_handling = drop-trailing-slash` and `not_found_handling = 404-page`. The upload receipt reported `write_performed: true`, `activation_required: true`, `serving_claimed: false`.

## Activation and serving

Both `celld-site` units were restarted after the upload. Both health endpoints returned `{"ok":true}`.

Probes through each public ingress returned the exact local build bytes:

- `/` on both hosts: BLAKE3 `2dfa0606d93bb7b74fb9f1f9f74f0396a212eac7a8b18584db1388abbfa99b8b`, 2161 bytes, HTTP 200.
- `/docs/aspen/architecture/overview/` on both hosts: BLAKE3 `5c7e940c456b92f26a29dd6c1f7b3160abcf52dbd87ed33ea1623125bd6b927b`, 8143 bytes, HTTP 200.
- `/missing` on aspen3: HTTP 404 with the generated 404 page body, BLAKE3 `9fdf5be447c1f3279e63302812237efe2c30179410c235a7f2ccb9ad61c7f945`.

The trailing-slash probe is the compatibility case: generated links end in `/`, ingress removes only the final slash, and Celld returns the nested `index.html`.

## Deployed systems

- aspen3: `/nix/store/ny6g6hfr1w6q1y95yrmgg6v35c1dwhwq-nixos-system-aspen3-26.11.20260819.afe3d8a`
- britton-desktop: activated directly at `/nix/store/dk6bw2wff2s0q0grgb7fvpznsyy7cm3i-nixos-system-britton-desktop-26.11.20260819.afe3d8a`; the current running generation during final verification is `/nix/store/fxh8jb3phcxyhpf9vjakpx7cdar8x0pz-nixos-system-britton-desktop-26.11.20260819.afe3d8a` from a concurrent rollout that also carries the Site fleet units, which remained active and serving throughout.

The pre-existing lab fleet stayed untouched on both hosts: `celld.service` active with listeners on `39200`/`39201` and bucket `onix-celld-lab`.

## Upstream defects found

Celld `0.3.0` exhibited three defects during rollout. Each has a bounded workaround in this repository and no claim about upstream fixes:

1. Non-root request paths ending in `/` are rejected before asset routing. Workaround: `celld-site-ingress` strips exactly one trailing slash and the deployment uses `drop-trailing-slash`.
2. `AWS_SHARED_CREDENTIALS_FILE` is ignored; the client falls back to EC2 instance metadata. Workaround: the publisher secret carries plain AWS environment variables and `AWS_EC2_METADATA_DISABLED=true`.
3. A listener port inside the Linux ephemeral range can be occupied by an outbound socket before Celld binds. Workaround: Site ports `32110`-`32112` and a repository check that rejects Site ports at or above `32768`.

## Validation

- Nickel contract validation and `nickel format --check` passed for the schema, inventory, and fixtures.
- `checks.x86_64-linux.celld-settings` and `checks.x86_64-linux.celld-generated` passed on this branch, including the new negative cases for proxy ports, loopback backend addresses, and publisher credential ownership.
- Complete NixOS systems for both fleet hosts built from this branch.
- Cairn structural validation passed after sync and archive.

## Non-claims

- Celld `0.3.0` is alpha software and is not safe for hostile multi-tenant use.
- A two-node fleet has less failure-domain coverage than the three-node lab fleet. This change makes no node-loss tolerance claim and no live outage test was run for the Site fleet.
- These probes prove serving at probe time through each private Tailnet endpoint only. No public Internet ingress, TLS, long-duration availability, load, or disaster-recovery claim is made.
- The concurrent Kache rollout on the same hosts is out of scope for this evidence; aspen3's Kache units from that unmerged branch were removed by this fleet's aspen3 activation and require that branch to merge this one and redeploy.
