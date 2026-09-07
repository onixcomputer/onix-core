# Restored forge and fresh Cargo acquisition

This checkpoint supersedes the missing-route and Cargo-acquisition blockers in `namespace-deployment-2026-09-07.md`.

## Preserve the newer host

An alternate Git index captured the current SearXNG sources at tree `8c09bc408f9798b87f79d66c1f22f0be89e2328c`. The primary checkout and its index remained unchanged.

The isolated branch retained the newer `llm-client` tag, hidden ready panel, default Kagi selection, and Kagi health monitor. The first comparison exposed missing health units and configuration. Those differences were corrected before deployment.

Code commit `1bd4b5ac5bc0c35ce7dd4340c7657499d92414ce` supplied the final metadata-free archive. The final comparison against live system `r03szdj5sdh1sxz0yypvhkpvl25sc1h5` showed no unit or tool removal. SearXNG package paths changed after source formatting. Existing behavioral controls still pass. The intended forge changes remain the Campaign seed entry and exact read routes.

SearXNG module, Kagi session, Radicle node policy, and Campaign scope checks pass. Repository hooks and the Aspen1 system build pass. Clan variables passed preflight. A live-system guard required the observed `r03szdj5sdh1sxz0yypvhkpvl25sc1h5` state before activation.

Clan deployed:

```text
/nix/store/2z8a8cdrdaa9vdcha554inq517rrbkx3-nixos-system-aspen1-26.11.20260819.afe3d8a
```

Radicle node, HTTP gateway, nginx, uWSGI, and the Kagi health timer are active. The policy reconciler and the last health run report success. The Radicle node identity remains `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`.

## Repair the client without source mutation

An isolated Git fixture reproduced missing namespace HEAD. Adding a namespace HEAD changed advertisement, but Radicle requires qualified namespace refs and validates signed refs. No such mutation entered live storage.

ChaosControl code `3cc7324c79fd66d4d6c4604b88e0c63b46cd467b` supplies a scoped Cargo 1.98.0 repair. Its typed configuration selects direct object-ID fetches only for the canonical Campaign URL. Other remotes retain stock behavior. Missing objects and server denials remain errors.

The repair passes 18 upstream Git-related library tests and a Nix fixture with positive and negative controls. The fixture covers a fresh locked fetch, exact payload execution, unknown revisions, missing default HEAD, unlisted URLs, and malformed configuration.

## Fresh public proof

The consumer run used a frozen archive, an empty Cargo Git cache, and an empty target directory. Only the crates.io registry cache was shared. Cargo fetched the exact Campaign revision from the ordinary public HTTPS endpoint. No Git cache was preloaded.

The exploration library passed 211 tests with one existing ignored KVM placeholder. Focused strict Clippy passed. The new Cargo database passed strict Git object validation. Its archive matched the reference bytes and BLAKE3 digest:

```text
78136b386be193f30ee75150eaf56f2576413cb70c4fc0b304983187008480f1
```

A separate empty bare repository fetched older code commit `cb4d2823d3fb4524eb3f5b39f2cfd19aed60855f` and passed strict object validation.

Root discovery returned 200. Unknown-repository, receive-pack discovery, and receive-pack POST controls returned 404. Root HEAD still points to `refs/heads/main` at `10182365ec53e20a0fd4c02cfc188ac2fd1a5706`. No publisher namespace HEAD exists.

## Boundaries

The namespace endpoints alone do not repair stock Cargo. The consumer uses its declared client profile and the ordinary Campaign URL. This profile is not source authorization or a general Cargo compatibility claim.

No source branch, signature floor, private-repository scope, or CI target changed. No mirror, runtime override, cache bootstrap, or success fallback entered the deployment.

Main integration, desktop and Aspen3 rollout, lifecycle closure, and Campaign-backed exploration remain open. Detailed commands and logs remain under the operator evidence root, including `public-cargo-final-tests.log`, `public-cargo-final-clippy.log`, `public-cargo-runtime-proof.log`, and `forge-restored-deploy.log`.
