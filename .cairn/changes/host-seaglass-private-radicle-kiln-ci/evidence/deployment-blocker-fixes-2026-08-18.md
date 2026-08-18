# Deployment blocker fixes — 2026-08-18

## Prime Agent package

The prior package ran `npm install` against semver ranges during a
fixed-output build. The upstream release archive has no lock file. A
later dependency resolution changed the output from the reviewed hash.

The package now keeps the upstream release archive as the program source.
It adds a generated `package-lock.json` and uses `buildNpmPackage` with
this dependency identity:

```text
sha256-E/ZXdxQBixnayrrnYKFfwCbaGUrQGs5PZVg/DSMZ03s=
```

Nix fetches that dependency set first. The package build then installs
from the fixed cache with scripts disabled. The resulting package is:

```text
/nix/store/hiakhkbjx37lj812x5psi0h340yn3cz6-prime-agent-0.7.0
```

`nix build --no-link -L .#prime-agent` passed. Its install check proved
that `prime-agent --version` returns `0.7.0`. The negative install check
proved that an unknown option returns failure.

## Radicle HTTP package review

The reviewed package changed from `0.25.0` to `0.27.0` through the pinned
Nixpkgs input. The historical bootstrap receipt remains bound to
`0.25.0`. The current package gate now has a separate identity.

| Identity field | Reviewed value |
|---|---|
| Version | `0.27.0` |
| Radicle repository | `z4V1sjrXqjvFdnCUbxPFqd5p4DtH5` |
| Release tag | `refs/tags/releases/0.27.0` |
| Release commit | `9469fc7d32bab4c824b82afa8abcd1649a987e92` |
| Nix sparse-source hash | `sha256-OJrHV5WdFNzoYrOkqpN1ctrJDB3JTJhH54q/C6IV9ZU=` |
| Cargo dependency hash | `sha256-FjYhw27pAX9Tilgm/Tg18Vkv4/K5kEFJAbhv1mDY0rg=` |
| Package output | `/nix/store/ijar1l4xkd90kdqdzqrvkdinbhdn0zd0-radicle-httpd-0.27.0` |

The `0.26.0` release added streamed Git operations and archive downloads.
The `0.27.0` release moved synchronous repository reads to the blocking
pool and added faster statistics paths. It also excludes empty job COBs.

The public Onix Nginx path remains read-only. It exposes upload-pack
routes only. The package change does not add a public receive-pack route
through the Onix configuration.

`nix build --rebuild --no-link -L .#radicle-httpd` rebuilt the package.
The build ran 98 tests with zero failures:

- 64 Radicle HTTP library tests;
- 6 Radicle HTTP command tests; and
- 28 Radicle search tests.

The command tests include accepted timeout parsing and rejected zero,
negative, empty, and malformed timeout values. The package version check
also passed.

`nix build --no-link -L .#checks.x86_64-linux.radicle-node-policy`
passed after the identity update. The gate contains a positive observed
identity case and a negative unreviewed-revision case.

## Desktop closure

The full desktop closure passed after both fixes:

```text
nix build --option allow-import-from-derivation true --no-link -L \
  '.#nixosConfigurations."britton-desktop".config.system.build.toplevel'
```

Nix produced this closure:

```text
/nix/store/kxyg5zx00girhfw35k4vf1dfbzqq2f1s-nixos-system-britton-desktop-26.11.20260803.104240a
```

The build also ran `cib config` against the generated broker file. It
accepted the exact Seaglass repository filter, published Kiln adapter,
two-hour timeout, eight MiB output bound, and single-adapter limit.

## Non-claims

These checks prove package identity, reproducible dependency acquisition,
package tests, and the existing read-only Onix route shape. They do not
prove the behavior of every upstream API endpoint under hostile traffic.
They also do not prove the final desktop deployment.
