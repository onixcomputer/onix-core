# Developer engines: implementation and deployment boundary

The user requested GitHub, NixOS options, Home Manager, and Noogle engines.

## Implemented

- Native GitHub public repository search: `!gh`.
- NixOS unstable options through NixOS Search schema 51: `!nixopts`.
- Home Manager unstable options through the same backend with a separate document type: `!hm`.
- Offline search of a content-pinned public Noogle catalog: `!noogle`.

The engines are enabled under IT in the candidate configuration. General Kagi defaults and its private engine gate remain unchanged.
No personal GitHub or Kagi credential is used by these engines.
NixOS Search requires the read-only frontend pair that it publicly ships in its JavaScript client. This is not a personal secret.
The Noogle catalog contains 2,124 source records, with Nixpkgs revision 6e90d09d59dde7442b03cde4a2682b415f78848c.
Its Nix fixed-output hash and source notices are recorded in modules/searxng/DEVELOPERS.md and noogle-notices.txt.

## Checks

The baseline passed in task 1693.
Ruff and scoped Statix passed. Task 1907 passed the module, existing Kagi, and new developer-engine Nix checks.
The tests cover source isolation, invalid queries, malformed and oversized data, partial backend errors, URL parameter encoding, unsafe paths, aliases, ranking, missing results, and real engine loading.
The complete pinned Noogle catalog loads and resolves lib.mkIf. The developer-only package works without Kagi templates or credentials.

Direct public-backend probes returned services.openssh.enable for NixOS and programs.git.enable for Home Manager.
An anonymous live Obscura GitHub query returned 30 result articles and a GitHub repository link. GitHub already existed in the pinned SearXNG release.
The new three engines were not exercised through the live SearXNG service because activation stopped at the deployment preview.

## Blocked deployment

Candidate: /nix/store/vqn1s7fn489132cpq2m77wnxym81d39f-nixos-system-aspen1-26.11.20260819.afe3d8a.
Live preview baseline: /nix/store/2z8a8cdrdaa9vdcha554inq517rrbkx3-nixos-system-aspen1-26.11.20260819.afe3d8a.

The package preview showed only a SearXNG change, but also listed an unexpected Nginx restart.
The Nginx configuration diff revealed removal of four existing Git routes for repository z2scC9MCm3pxk9mX4FEidRKabQ5LN, including its publisher namespace.
The primary source does not contain that repository admission. The Radicle module also enforces a governed repository allowlist, so an ad-hoc extra route would not be a safe substitute for source reconciliation.

No activation occurred. No forge route was removed or changed. The copied candidate is preview-only.
A reconciled, approved forge configuration is needed before this full-system deployment can proceed.
Repository-wide commit-hook blockers from the preceding task remain. No commit or push occurred.
