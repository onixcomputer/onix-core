# Broker wire cutover attempt

Date: 2026-08-29

## First real event

Onix activated Aspen route closure `/nix/store/6abs8ks8fd4bs928za37xw8p3ddjqir1-nixos-system-britton-desktop-26.11.20260819.afe3d8a` at an empty broker queue boundary.

Canonical Seaglass commit `ee03ebc2d4315f8c1931767c19e17083aa125549` produced a real default-branch event. Broker run `5175bab4-cac9-467a-8d2d-b19eeb5e29ce` passed repository, `flake.nix`, and default-branch filters. The adapter then exited with code `2` and diagnostic:

`radicle_json: broker input is not a supported deployed broker request`

No Aspen host operation or provider report was created. The event failed before durable ingress.

## Rollback

The broker queue was empty after the failure. The machine immediately returned to verified legacy closure `/nix/store/q89zgccfjbr5r7j4g73x0mi7nfg0v82p-nixos-system-britton-desktop-26.11.20260819.afe3d8a`. The legacy broker, Aspen host, and Lattice service were active after rollback.

## Repair cohort

The production Kiln input now pins `8c9338e5c10a0e16ee3042d11583ccccf6efe7e9`. This revision admits the published Radicle CI broker `0.31` envelope and pre-admits protocol input before profiles, state, sockets, or runtime composition.

Focused production module, Nickel profile, Seaglass continuity, and machine-evaluation checks passed. The Seaglass check proved malformed input returns `radicle_json` without an available Aspen socket. The final built adapter was `/nix/store/wb8508dg96k394v61gagfzsmqa69i2gf-kiln-aspen-ci-adapter`.

## Non-claims

This evidence proves one bounded failed cutover, explicit rollback, and static admission of the repair cohort. It does not prove a successful real event, provider truth, CI correctness, status publication, production availability, distributed exactly-once execution, completed cutover, or release eligibility.
