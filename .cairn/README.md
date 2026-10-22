# onix-core Cairn lifecycle

This directory contains native Cairn lifecycle artifacts for planned `onix-core` changes. Do not create or update OpenSpec artifacts for normal change work.

Use `/home/brittonr/git/OnixResearch/cairn` as the local Cairn source checkout for the canonical project `https://github.com/OnixResearch/cairn`, authenticated with SSH remote `git@github.com:OnixResearch/cairn.git`. `/home/brittonr/git/cairn` is a symlink to it, which `nix run path:` and the Cairn policy loader both reject.

- `specs/`: accepted specifications
- `changes/`: active change packages
- `archive/`: completed change archives

Use the local Cairn source checkout for validation:

```sh
nix run path:/home/brittonr/git/OnixResearch/cairn#cairn -- validate \
  --root /home/brittonr/git/onix-core \
  --policy /home/brittonr/git/OnixResearch/cairn/cairn-policy/generated/cairn-policy.json
```

See `AGENTS.md` ("Cairn lifecycle") for gates and for the manual steps that
`cairn change create` and `cairn archive` do not perform here.
