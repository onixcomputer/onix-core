# onix-core Cairn lifecycle

This directory contains native Cairn lifecycle artifacts for planned `onix-core` changes. Do not create or update OpenSpec artifacts for normal change work.

Use `/home/brittonr/git/cairn` as the local Cairn source checkout for the canonical project `https://github.com/OnixResearch/cairn`, authenticated with SSH remote `git@github.com:OnixResearch/cairn.git`.

- `specs/`: accepted specifications
- `changes/`: active change packages
- `archive/`: completed change archives

Use the local Cairn source checkout for validation:

```sh
nix run path:/home/brittonr/git/cairn#cairn -- validate \
  --root /home/brittonr/git/onix-core \
  --policy /home/brittonr/git/cairn/cairn-policy/generated/cairn-policy.json
```
