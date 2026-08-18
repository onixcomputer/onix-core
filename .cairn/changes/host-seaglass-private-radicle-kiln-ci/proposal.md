## Why

Seaglass moves from GitHub-hosted development to a private Radicle
repository as the operator's canonical forge. The repository already
exists at private RID `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk` on the
`brittonr` personal node.

The CI execution for the private repository must run on
`britton-desktop`. This machine already runs the personal Radicle node,
is the reviewed backup target for the production Radicle seed, and stays
permanently powered. It is the operator-authorized CI host.

Kiln is the provider-neutral CI control plane at
`OnixResearch/kiln`. It has no deployed consumer yet. Its Radicle broker
adapter conforms to the Radicle CI broker protocol, but the shipped
reference service is a local fixture that executes no build. This change
makes Seaglass the first Kiln consumer on `britton-desktop`, with broker
and execution wiring owned by `onix-core`.

## What Changes

- Add `kiln` as a flake input from its public Radicle RID at a reviewed
  revision. This input exists because `onix-core` must package and deploy
  the Kiln adapter binary.
- Seed the Seaglass private RID into the `britton-desktop` Radicle
  storage that the CI broker watches, replicated with scope `all`.
- Deploy the Radicle CI broker with the Seaglass trigger filter and two
  registered adapters: the Nix adapter for execution and the Kiln Radicle
  adapter as the control-plane surface.
- Move the Seaglass CI rails that GitHub Actions runs and that are not
  already flake checks into the Seaglass flake `checks` set.
- Keep the GitHub remote as a declared read-only mirror. Retire GitHub
  Actions only after parity evidence on the private CI path.

No `seaglass` flake input is required. The adapter builds the exact
pushed revision directly from the CI node's Radicle storage
(`git+file://$RAD_HOME/storage/$rid?rev=$oid`). A private seed HTTP
endpoint is needed only if a machine or flake consumes Seaglass as an
input, which is out of scope for this change.

## Impact

- **Files**: `onix-core` `flake.nix`, a new CI service module under
  `modules/`, seed policy, and focused checks; `seaglass` flake and
  README/docs.
- **Risk**: first deployed Kiln consumer; private seed HTTP exposure must
  not leak undeclared repositories; building the Seaglass checks set is
  heavy on the desktop Nix build budget.
- **Non-goals**: do not rework the production Aspen1 Radicle seed policy,
  do not build a new Kiln executor crate in this change, do not migrate
  Seaglass patch review to Radicle COBs.
- **Testing**: positive acquisition and check-run evidence plus negative
  rejection fixtures for undeclared seed access and broken Kiln adapter
  links, and Cairn validation and gates.
