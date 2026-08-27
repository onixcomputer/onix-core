# Site Celld fleet runtime rollout evidence

Date: 2026-08-26

## Static and build evidence

The Site Celld branch was combined with the Kache fleet branch before final deployment. The combined tree passed:

- Celld positive and negative Nickel settings fixtures;
- Celld semantic positive and negative settings tests;
- generated runtime-name, unit, port, bucket, provisioner, publisher-credential, loopback-backend, and ingress checks;
- complete NixOS builds for Aspen3 and `britton-desktop`;
- Cairn structural validation before runtime completion.

The active change was moved from the legacy `cairn/` path to the repository-required `.cairn/` path.

## Deployment

The combined closure was deployed to Aspen3 and `britton-desktop`. Both nodes report active:

- `celld-site.service`;
- `celld-site-ingress.service`;
- RustFS;
- the separate `celld-lab` service where configured.

The Site service uses bucket `onix-site-celld`, public port `32110`, internal port `32111`, and loopback backend port `32112`. The existing lab fleet remains on bucket `onix-celld-lab` and ports `39200` and `39201`.

## Asset and listener evidence

Both private listeners returned HTTP 200 for:

- `/__celld/health`, with an 11-byte response;
- `/`, with the Aspen Documentation page;
- `/blog/`, with the same 1,915-byte asset;
- `/blog`, proving that the private ingress accepts the normalized route form.

Observed endpoints:

- `http://100.108.13.4:32110`;
- `http://100.110.43.11:32110`.

The uploaded Site asset was already active when this operator took over the stopped deployment agent. The bounded serving probes were repeated after the combined Kache deployment restarted both hosts.

## Authority evidence

The Site credential listed `onix-site-celld` and was denied access to `onix-celld-lab`. The Kache credential was separately denied access to `onix-niks3`. These probes confirm that the Site authority did not widen during branch combination.

The publisher credential remains owned by `brittonr`, scoped to the Site bucket, and stored outside the repository.

## Recovery observation

A concurrent niks3 upload storm temporarily delayed RustFS list and conditional-write operations. The Aspen1 lab Celld node self-fenced as designed when lease renewal became ambiguous. After durable upload workers were paused, RustFS latency recovered and the lab node reacquired authority. Its health endpoint returned HTTP 200.

The Site endpoints remained healthy after the combined Aspen3 and desktop deployment.

## Non-claims

This evidence proves only the observed private Tailnet health, asset, and authority checks. It does not prove public Internet service, long-duration availability, or tolerance of every two-node failure pattern.
