# Design: Install the omp coding agent on two workstations

## Context

The accepted `llm-agents` Clan instance installs `pi`, `openspec`, and
per-machine agents on every machine tagged `llm-client`. That tag covers the
laptops and the Aspen servers. `omp` comes from the same pinned flake input,
but only `britton-desktop` and `aspen3` should run it.

Clan instances are the inventory's unit of membership. A role can be
targeted by tag or by explicit machine, and the `llm-agents` module maps its
`packages` setting onto `environment.systemPackages` through
`lib.mkSettings`. The setting is list-typed, so machine-level entries are
additive for the machine that declares them.

## Decisions

### 1. Add a machine-scoped instance instead of widening the shared role

**Choice:** Declare a new `omp-agents` instance that reuses the existing
`llm-agents` module and names `britton-desktop` and `aspen3` as its only
targets.

**Rationale:** The shared role is tag-targeted, so widening it would install
a large agent build on five unrelated hosts. A machine-scoped instance keeps
the membership explicit and reviewable, and it needs no new module, schema,
or tag.

### 2. Take the package from the pinned llm-agents input

**Choice:** Reference the agent by name in the instance settings, exactly as
the shared role does. Do not add a flake input, a lock node, or a version
pin.

**Rationale:** `llm-agents` is already pinned and already supplies the other
agents on these hosts. A second source for the same program would let the
two drift.

### 3. Verify the configuration, not a hand-copied derivation

**Choice:** The focused check reads the evaluated
`environment.systemPackages` of the three machines it cares about, and the
build check compiles the package entry taken from that same list.

**Rationale:** A check that names the package directly would still pass if
the inventory stopped wiring it up. Reading the evaluated list proves the
scope and the artifact together.

### 4. Pin the compiler bun the agent's template needs

**Choice:** Add a repository package pin for bun 1.3.13 through
`multiverse.lock`, and compile the agent with it. Rebuild the bun2nix helper
against that same bun, so the build hook uses it too. Keep both machines on
their existing nixpkgs pins.

**Rationale:** `llm-agents` writes the agent into a bun 1.3.14 runtime
template, and takes the compiler from the consumer's nixpkgs. nixpkgs moved
bun to 1.4.2 on 2026-09-13, and that compiler writes the template with an
empty embedded prelude; the compiled agent then fails its own smoke test.
Building the agent with the older bun reproduces the combination upstream
tests, and it keeps the workaround scoped to one package instead of moving
a machine's nixpkgs backwards.

### 5. Keep deployment attributable to the live lineage

**Choice:** Commit the inventory, check, and compiler changes on the branch
these machines deploy from, and deploy from the trees they already run.

**Rationale:** The two machines run feature-branch states that are not
`origin/main`, so deploying from `origin/main` would roll back accepted work
on both hosts. The agent addition must ride the lineage the machines already
run.

## Risks and Controls

- A source build of `omp` is long. The build runs in `pueue` and is cached
  in the store and the binary caches afterward.
- A machine-scoped role could be mistyped and silently target nothing. The
  positive check fails when either named machine lacks the package.
- The instance could over-reach. The negative check fails when an
  unselected `llm-client` host gains the package.

## Non-Claims

This change does not configure the agent, provide credentials, model
access, or any agent runtime authority. It proves availability of the
package on two hosts, not agent correctness.
