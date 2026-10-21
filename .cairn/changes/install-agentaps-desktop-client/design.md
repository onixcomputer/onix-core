## Context

`britton-desktop` and `aspen3` are the workstations that run the terminal
coding agents (`omp`, `pi`, and others from `llm-agents`). Agentaps is a
GPUI desktop client for agents that speak ACP. It is published on crates.io
and GitHub but is packaged in neither nixpkgs nor `llm-agents.nix`. onix-core
takes custom packages from the onixpkgs overlay, and `pkgs/` here keeps only
packages bound to onix-core.

## Decisions

### Decision: Define the package in onixpkgs

**Choice:** Add `pkgs/agentaps/default.nix` to onixpkgs, publish onixpkgs
`main`, and relock onix-core's `onixpkgs` input. The working branch gains
no flake input and no package definition.

**Rationale:** AGENTS.md keeps package definitions in onixpkgs, and the
recent migration moved onix-core's portable packages there. The package
bakes in no onix-core data.

### Decision: Pin upstream main instead of the v0.2.1 release

**Choice:** Pin commit `9d526af` (2026-09-28) as version
`0.2.1-unstable-2026-09-28`.

**Rationale:** The operator chose this pin. v0.2.1 (2026-09-25) lacks SSH
projects, Web Connect, and conversation forks, which the upstream README
describes. Main also replaces the GPUI CE forks with GPUI Kit 0.7.

### Decision: Load GPU and windowing libraries through RUNPATH

**Choice:** Add the Vulkan loader, libglvnd, and Wayland library
directories to the binary's RUNPATH in `postFixup`. Do not wrap the binary
with `LD_LIBRARY_PATH`.

**Rationale:** GPUI's wgpu backend loads `libvulkan.so.1` or `libEGL.so.1`
at runtime, and its Wayland client loads the Wayland libraries the same
way, so the linker-derived RUNPATH does not list them. Agentaps spawns
agents, `git`, and `ssh`. A wrapper's `LD_LIBRARY_PATH` would pass into
each of those processes, while RUNPATH applies to the Agentaps binary alone.

### Decision: Install through each machine's Home Manager package list

**Choice:** Add `agentaps` to `home-manager.users.brittonr.home.packages`
in both machine configurations.

**Rationale:** The `llm-agents` module installs only packages from the
`llm-agents` flake, and the `llm-client` tag also covers the laptops and
Aspen servers. Each machine's list already holds its per-user desktop
applications, such as `librepods` and `rnote`, and names exactly the two
target hosts.

### Decision: Deploy each machine from the lineage it runs

**Choice:** Deploy `aspen3` from this working tree. Deploy
`britton-desktop` from a port commit on the commit it runs, `e8d1a26c` on
`underclass-mesh-desktop`. The port adds the `onixpkgs` input and takes
`agentaps` from that flake's `packages` output.

**Rationale:** aspen3 reports `c5001ff2-dirty`, the working tree's own
lineage, and the operator approved shipping that tree's uncommitted
changes. The desktop reports `e8d1a26c`. That commit has 32 commits the
working branch lacks, the working branch has 27 it lacks, and their trees
differ in 397 files. Deploying the working tree there would roll back the
desktop's Qwen3.8 and Mesh-LLM work. Earlier desktop additions (`omp`,
`omnibin`, and the Qwen mask) rode the deployed lineage the same way. That
lineage predates the overlay, so the port takes the package from the flake
output instead of applying the overlay, which would replace its local
packages.

## Risks / Trade-offs

- An unreleased pin can carry defects. Control: build the package, check how
  it resolves its libraries, and launch it on a headless compositor before
  wiring it in.
- The aspen3 tree carries uncommitted work outside this change. Control:
  review its closure difference before activation, and stop if it removes
  or downgrades packages unexpectedly.
- The two lineages now reach Agentaps in different ways. Control: both
  resolve the same onixpkgs revision. When the lineages merge, the overlay's
  `pkgs.agentaps` replaces the desktop's direct `packages` reference.
- aspen3 deploys can stall or lose a copied closure to its `min-free`
  garbage collection. Control: follow the AGENTS.md procedure, which roots
  the built toplevel and compares `/run/current-system` before any rerun.

## Non-Claims

This change does not install ACP adapters, provide agent credentials,
configure a SecretSpec provider for phone pairing, or host Web Connect. It
proves that the client is installed, resolves on `PATH`, and starts on the
two hosts. It does not prove agent sessions work end to end.
