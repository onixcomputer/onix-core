## Context

The migration base is `c5001ff2` plus the uncommitted working tree of 2026-09-27, including the in-flight laya, laya-cpp, arxiv-corpus, mesh-research, underclass-mesh-gateway, nix-grpc-store, and tenstorrent-compat packages. Machines resolved migrated packages three ways: `pkgs.callPackage ../../pkgs/<name> { }` against the machine package set, `self.packages.<system>.<name>` built from plain nixpkgs, and seven attributes that `shared-nix.nix` injected from `self.packages`. Check harnesses evaluated modules against adios-flake's plain nixpkgs.

## Decisions

### Decision: Machines take packages from the overlay

**Choice:** `shared-nix.nix` puts `inputs.onixpkgs.overlays.default` first in `nixpkgs.overlays`, and modules, profiles, and machines refer to `pkgs.<name>`. The radicle-node and radicle-httpd injections stay, because they are nixpkgs packages rather than migrated ones.

**Rationale:** This is the overlay's purpose: one package set in which later overlays and the machine configuration see the same packages. Machine package sets differ from plain nixpkgs only in overlays and configuration that none of the migrated packages use, so the seven formerly injected packages keep their derivations.

### Decision: The DGX module brings the overlay itself

**Choice:** `modules/dgx-machine` sets `nixpkgs.overlays = [ inputs.onixpkgs.overlays.default ]`.

**Rationale:** DGX devenv machines import only this module, not the Clan tags that include `shared-nix.nix`. nixpkgs also defines `sendme`, so without the overlay `pkgs.sendme` would silently resolve to a different package. On a Clan machine that also has `shared-nix.nix`, the overlay applies twice with identical results.

### Decision: Check harnesses use an overlaid package set

**Choice:** `flake-outputs/checks.nix` builds its own `pkgs` from `nixpkgs` with the onixpkgs overlay and passes it to every check file. Checks that asserted on flake packages (`celld-package`, `bookshelf-package`, `kache-package`, `mesh-llm-sidecars`, the radicle-ci-runner checks, and the Collie integration check) now use `pkgs.<name>`. The aarch64 mesh-llm check reads `self.inputs.onixpkgs.packages.aarch64-linux.mesh-llm`.

**Rationale:** adios-flake instantiates nixpkgs without overlays. Harnesses such as the iroh-ssh parity check and the mesh-llm fixture evaluate modules outside a machine, so they must see the same package set as machines. The migrated packages built over plain nixpkgs with the overlay are the derivations that `self.packages` used to provide.

### Decision: Read package data through the package

**Choice:** The OMP research bundle copies `${pkgs.mesh-research.src}/operations.json`, and the radicle-ci-runner check reads `${runnerPackage.src}/Cargo.lock`, instead of reaching into `pkgs/` paths.

**Rationale:** Both files belong to their packages' sources. Referring to the package keeps the module independent of onixpkgs' file layout. It changes only the store path from which the file is copied.

### Decision: Keep inventory, private-flake, and fork packages here

**Choice:** `pkgs/` keeps dgx-machine, tenstorrent-compat, nix-grpc-store, and aspen-uma-helper.

**Rationale:** They depend on onix-core's DGX inventory, the private tenstorrent.nix flake, or onix-core's Nix fork and its nixpkgs snapshot. Moving them would make every onixpkgs consumer lock private or fork inputs, or would add a package that cannot build without onix-core data.

## Risks / Trade-offs

- The `onixpkgs` input fetches `github.com/OnixResearch/onixpkgs` over SSH. A host that evaluates onix-core needs the same OnixResearch SSH access that the `cairn` and `lattice` inputs already require.
- onix-core CI no longer builds `package-*` checks for migrated packages. Machine toplevels, the dev shell, and module checks still build every migrated package they contain. The rest (for example hx-oil, updater, and merge-when-green) are built only by onixpkgs' own `nix flake check`, which has no CI yet.
- A package set that lacks the overlay silently resolves `dumbpipe`, `herdr`, `iroh-ssh`, `sendme`, `sone`, and `tuicr` from nixpkgs. Every place that instantiates nixpkgs for machines or checks must apply the overlay.
- The migrated laya-cpp package took two formatter fixes in onixpkgs. The newline added to its copied `model-manifest.json` changes the Laya unit on aspen1, so the next aspen1 deployment restarts that service.

## Measured Verification

The migration base was reproduced as a worktree at `c5001ff2` with the base's uncommitted changes applied. Its tracked file contents and executable bits match the pre-change working tree, and it produced the working tree's `aspen1` toplevel derivation. The "after" state is this working tree with `onixpkgs` locked. x86_64-linux checks were evaluated per attribute with nix-eval-jobs.

- Toplevels: aspen2, aspen3, bonsai, britton-fw, chv-dev1, chv-dev2, and chv-dev3 keep their derivations. aspen1 differs only in the Laya bundle's `model-manifest.json`, which gained a trailing newline. britton-desktop differs only in `omp-research-tools`, whose `operations.json` is now copied from the mesh-research source instead of from a standalone store path. The seven packages that `shared-nix.nix` used to inject keep their derivations.
- Checks: 165 of the 173 remaining checks keep their derivations, including `collie-integration` and `kache-package`. The removed checks are the migrated `package-*` checks and the two Collie package tests that moved to onixpkgs. `pre-commit`, `devShell-ci`, `no-stale-color-refs`, `secrets`, and `vars` differ because they read the changed source tree or the treefmt configuration. `radicle-ci-runner-policy` differs because it reads `Cargo.lock` from the runner's source. `nixos-aspen1` and `nixos-britton-desktop` differ as described above.
- Pre-existing evaluation failures are unchanged: `dgx-devenv-disko`, `dgx-machine-inventory`, `dgx-spark-power`, and `dgx-spark-tag` call `modules/llamacpp-server/mk-nixos-config.nix` without `config`, and `devShell-default` needs impure evaluation for devenv.
- The impure `devShells.x86_64-linux.default` evaluates. It differs in the Python environment, which lost vcrpy and pytest-vcr, in the treefmt and pre-commit configuration, and in devenv paths that depend on the evaluation directory.
- Remaining packages: every `packages.<system>` attribute onix-core still exports keeps its derivation on x86_64-linux, aarch64-linux, and aarch64-darwin.
- deadnix and statix pass on every touched Nix file, and nixfmt passes on all of them except `flake-outputs/_mesh-llm-checks.nix`, whose unformatted line 114 predates this change.
- Not evaluated: pine and utm-vm (aarch64-linux) need the aarch64 wasm plugins built through qemu for inventory evaluation. That build ran for an hour without finishing and was stopped. britton-air (aarch64-darwin) needs an aarch64-darwin builder, which this workstation lacks. Across the repository, every use of the six names that nixpkgs also defines refers to a migrated package that previously came from onix-core `pkgs/`: `tuicr`, `dumbpipe`, and `sendme` in the dev tools profile, `sone` in the media tag, `sendme` in the DGX module, and `herdr` on aspen3 and britton-desktop. No configuration previously took these names from nixpkgs.

## Library and Package Updates

onix-core's `lib/kache-nix-rust.nix` moved to onixpkgs as `lib.kacheNixRust`, with the wrapper contract check. The changebot example now takes the library as its `kacheNixRust` argument. `flake-outputs/_kache-nix-rust-checks.nix` keeps the checks that read britton-desktop's configuration and the example check. Relocking onixpkgs to `56a93169` brings iroh-ssh 0.2.12 with the connection-type evidence patch, the repaired horizon, and `mesh-llm-headless`, which onix-core does not use.

Measured against the parent commit `023a7ac3`:

- `flake.lock` changes only the `onixpkgs` and `onixpkgs/horizon` nodes.
- Machines: bonsai's `iroh-ssh` service moves to iroh-ssh 0.2.12, which also changes its man-page index. aspen1, aspen2, britton-fw, chv-dev1, chv-dev2, and chv-dev3 differ only in `configurationRevision`. aspen3 and britton-desktop fail to evaluate on both commits on the `multiverse.lock` pin `eaad0894`.
- Checks: `kache-nix-rust-wrapper-contract` is gone, because onixpkgs runs it. `kache-nix-rust-changebot-example` and `kache-nix-rust-sandbox-settings` keep their derivations and build. The other checks that differ read the flake source tree or the commit revision, or are the four `dgx-*` checks that fail on both commits.
