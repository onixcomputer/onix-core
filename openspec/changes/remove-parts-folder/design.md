## Context

The flake has two directories for flake output logic: `flake-outputs/` (adios-flake modules) and `parts/` (implementation fragments). `flake-outputs/` imports everything from `parts/`, making `parts/` a layer that adds indirection without encapsulation or reuse.

The parts break into three categories:
1. **Trivial tool wrappers** (13 files, 4–9 lines): Return `{ packages.<name> = callPackage ...; }`. Called by `flake-outputs/tools.nix` which maps and merges them.
2. **Check/test helpers** (3 files, 23–84 lines): `machine-checks.nix`, `vars-checks.nix`, `vm-tests.nix`. Called by `flake-outputs/checks.nix`.
3. **Dev environment** (1 file, 365 lines): `dev-env.nix`. Called by `flake-outputs/dev-env.nix` which is a 14-line pass-through.

## Goals / Non-Goals

**Goals:**
- Single directory (`flake-outputs/`) for all flake output logic
- Remove the `parts/` → `flake-outputs/` indirection
- Keep every flake output byte-identical

**Non-Goals:**
- Restructuring `flake-outputs/` itself or changing the adios-flake module pattern
- Moving `sops-viz.nix` tool definitions into `pkgs/` (they use inline `mkDerivation`, not `callPackage`)
- Refactoring the dev-env or check logic — just moving it

## Decisions

**Inline trivial tools into `flake-outputs/tools.nix`.**
The 13 tool parts are each a single `callPackage` expression with an optional platform guard. Inlining them into a single `let` block in `tools.nix` replaces the `map callPart [ ... ]` + `foldl' recursiveUpdate` pattern with a plain attrset. Fewer files, less machinery, same result.

Alternative: move the files into `flake-outputs/tools/`. Rejected because 4-line files don't warrant their own namespace.

**Move check helpers alongside their consumer.**
`machine-checks.nix`, `vars-checks.nix`, and `vm-tests.nix` are imported only by `flake-outputs/checks.nix`. Moving them to `flake-outputs/_machine-checks.nix` (underscore = private helper) keeps them next to the only call site. The `_` prefix makes it clear these aren't adios-flake modules.

Alternative: inline into `checks.nix`. Rejected — `checks.nix` is already a composition file and adding 170+ lines would hurt readability.

**Inline `dev-env.nix` directly into `flake-outputs/dev-env.nix`.**
The current `flake-outputs/dev-env.nix` is 14 lines that import and pass args. Merging the actual content removes the wrapper entirely. The combined file stays at ~365 lines, which is manageable for a single-purpose module.

## Risks / Trade-offs

**[Merge conflicts]** → Low risk. Only `flake-outputs/` files change, and they're rarely edited concurrently. No open branches touch these files.

**[Large `tools.nix`]** → The inlined tools add ~50 lines. With `sops-viz.nix` still being imported (170 lines of `mkDerivation` — too large to inline cleanly), the file stays under 100 lines. Acceptable.

**[`sops-viz.nix` stays as a separate file]** → Move it to `flake-outputs/_sops-viz.nix` alongside the other helpers. It's 170 lines of three `mkDerivation` expressions — inlining would bloat `tools.nix` past readability.
