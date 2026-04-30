## 1. Inline trivial tools into flake-outputs/tools.nix

- [x] 1.1 Replace the `map callPart` + `foldl' recursiveUpdate` pattern in `flake-outputs/tools.nix` with a direct attrset of package definitions, inlining all 13 trivial tool parts (ccusage, abp, branchfs, nix-eval-warnings, iroh-ssh, claude-md, tuicr, updater, buildbot-pr-check, merge-when-green, iroh-tools, tracey)
- [x] 1.2 Move `parts/sops-viz.nix` to `flake-outputs/_sops-viz.nix` and update the import path in `tools.nix`

## 2. Move check helpers into flake-outputs

- [x] 2.1 Move `parts/machine-checks.nix` to `flake-outputs/_machine-checks.nix`
- [x] 2.2 Move `parts/vars-checks.nix` to `flake-outputs/_vars-checks.nix`
- [x] 2.3 Move `parts/vm-tests.nix` to `flake-outputs/_vm-tests.nix`
- [x] 2.4 Update import paths in `flake-outputs/checks.nix` from `../parts/` to `./_`

## 3. Inline dev-env

- [x] 3.1 Replace `flake-outputs/dev-env.nix` pass-through wrapper with the actual content from `parts/dev-env.nix`

## 4. Delete parts and update docs

- [x] 4.1 Delete the `parts/` directory
- [x] 4.2 Update `CLAUDE.md` project structure to remove `parts/` references
- [x] 4.3 Run `nix flake check` to verify no broken imports and all outputs are intact
